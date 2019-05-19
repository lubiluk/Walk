//
//  PhotoController.swift
//  Walk
//
//  Created by Paweł Gajewski on 16/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class PhotoSearchController {
    var managedObjectContext: NSManagedObjectContext!
    
    private var observer: NSObjectProtocol?
    
    deinit {
        stopSearching()
    }
    
    func startSearching() {
        observer = NotificationCenter.default.addObserver(forName: Notification.Name.NSManagedObjectContextObjectsDidChange, object: nil, queue: .main) { [unowned self] (notification) in
            let request = NSFetchRequest<Checkpoint>(entityName: "Checkpoint")
            request.predicate = NSPredicate(format: "isSearched = NO")
            
            do {
                let checkpoints = try self.managedObjectContext.fetch(request)
                
                for checkpoint in checkpoints {
                    self.searchPhotoForCheckpoint(checkpoint)
                }
            } catch {
                self.failWithError(.checkpoint)
            }
        }
    }
    
    func stopSearching() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // A bit naive but in this app this there are no other data tasks
        URLSession.shared.getAllTasks { (tasks) in
            for task in tasks {
                if task is URLSessionDataTask {
                    task.cancel()
                }
            }
        }
    }

    enum SearchError: Error {
        case request
        case responseStatus
        case jsonParsing
        case searchUrl
        case apiKey
        case checkpoint
        
        var description: String {
            switch self {
            case .request:
                return "Search request failed."
            case .responseStatus:
                return "Server responded with non 200 status code."
            case .jsonParsing:
                return "Failed to parse response JSON."
            case .searchUrl:
                return "Invalid search URL."
            case .apiKey:
                return "Missing API key."
            case .checkpoint:
                return "Failed to fetch checkpoint."
            }
        }
    }
    
    private func failWithError(_ error: SearchError, underlyingError: Error? = nil) {
        
    }
    
    private func searchPhotoForCheckpoint(_ checkpoint: Checkpoint) {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "FlickrAPIKey") as? String else {
            failWithError(.apiKey)
            return
        }
        
        let searchUrl = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&content_type=1&lat=\(checkpoint.latitude)&lon=\(checkpoint.longitude)&radius=0.05&radius_units=km&extras=url_l&per_page=1&page=1&format=json&nojsoncallback=1"
        
        guard let url = URL(string: searchUrl) else {
            failWithError(.searchUrl)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            defer {
                // Indicate that the search has been performed no matter if successful
                DispatchQueue.main.async {
                    checkpoint.isSearched = true
                }
            }
            
            if let error = error {
                strongSelf.failWithError(.request, underlyingError: error)
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                strongSelf.failWithError(.responseStatus)
                return
            }
            
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let object = json as? [String:Any],
                let photos = object["photos"] as? [String:Any],
                let photoList = photos["photo"] as? [[String:Any]],
                let photo = photoList.first,
                let photoUrl = photo["url_l"] as? String else {
                    strongSelf.failWithError(.jsonParsing)
                    return
            }
            
            DispatchQueue.main.async {
                checkpoint.remoteUrl = photoUrl
            }
        }
        
        task.resume()
    }
 }
