//
//  PhotoController.swift
//  Walk
//
//  Created by Paweł Gajewski on 16/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation

class PhotoController {
    static let photoDownloadDidFinishNotification =
        NSNotification.Name(rawValue: "PhotoControllerPhotoDownloadDidFinishNotification")
    
    private static let photoUrlKey = "photoURL"
    
    var photos = [URL]()
    
    func addPhotoForLocation(_ location: CLLocation) {
        searchPhotoForLocation(location) { [weak self] (photoUrl, error) in
            if let photoUrl = photoUrl {
                self?.downloadPhotoWithUrl(photoUrl) { (savedUrl, error) in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    guard let savedUrl = savedUrl else {
                        return
                    }
                    
                    strongSelf.photos.append(savedUrl)
                    
                    let center = NotificationCenter.default
                    center.post(name: PhotoController.photoDownloadDidFinishNotification, object: strongSelf,
                                userInfo: [PhotoController.photoUrlKey: savedUrl])
                }
            }
        }
    }
    
    enum TaskError: Error {
        case responseStatus
        case jsonParsing
        case fileSaving
        case searchUrl
        case photoUrl
        case tempUrl
        case apiKey
        
        var description: String {
            switch self {
            case .responseStatus:
                return "Server responded with non 200 status code."
            case .jsonParsing:
                return "Unable to parse response JSON."
            case .fileSaving:
                return "Unable to save file."
            case .searchUrl:
                return "Invalid search URL."
            case .photoUrl:
                return "Invalid photo URL."
            case .tempUrl:
                return "Invalid temporary file URL."
            case .apiKey:
                return "Missing API key."
            }
        }
    }
    
    private func searchPhotoForLocation(_ location: CLLocation, completion: @escaping (String?, Error?) -> Void) {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "FlickrAPIKey") as? String else {
            completion(nil, TaskError.apiKey)
            return
        }
        
        let searchUrl = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&sort=interestingness-desc&content_type=1&lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&extras=url_o&per_page=1&page=1&format=json&nojsoncallback=1"
        
        guard let url = URL(string: searchUrl) else {
            completion(nil, TaskError.searchUrl)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                completion(nil, TaskError.responseStatus)
                return
            }
            
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let object = json as? [String:Any],
                let photos = object["photos"] as? [String:Any],
                let photoList = photos["photo"] as? [[String:Any]],
                let photo = photoList.first,
                let photoUrl = photo["url_o"] as? String else {
                    completion(nil, TaskError.jsonParsing)
                    return
            }
            
            completion(photoUrl, nil)
        }
        
        task.resume()
    }
    
    private func downloadPhotoWithUrl(_ photoUrl: String, completion: @escaping (URL?, Error?) -> Void) {
        guard let remoteUrl = URL(string: photoUrl) else {
            completion(nil, TaskError.photoUrl)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: remoteUrl) { (url, response, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                completion(nil, TaskError.responseStatus)
                return
            }
            
            guard let url = url else {
                completion(nil, TaskError.tempUrl)
                return
            }
            
            do {
                let fileManager = FileManager.default
                let documentsURL = try
                    fileManager.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
                let savedUrl = documentsURL.appendingPathComponent(
                    remoteUrl.lastPathComponent)
                try fileManager.moveItem(at: url, to: savedUrl)
                
                completion(savedUrl, nil)
            } catch {
                completion(nil, TaskError.fileSaving)
            }
        }
        
        task.resume()
    }
    
    func deleteAllPhotos() {
        URLSession.shared.getAllTasks { (tasks) in
            for task in tasks {
                task.cancel()
            }
        }
        
        do {
            let fileManager = FileManager.default
            let documentsUrl = try
                fileManager.url(for: .documentDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: false)
            let fileUrls = try fileManager.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            
            for url in fileUrls {
                try fileManager.removeItem(at: url)
            }
        } catch {
            ()
        }
    }
 }
