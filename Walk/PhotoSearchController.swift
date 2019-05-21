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
            self.search()
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
    
    func retrySearches() {
        search()
    }
    
    private func search() {
        let request = NSFetchRequest<Checkpoint>(entityName: Checkpoint.entityName)
        request.predicate = NSPredicate(format: "remoteUrl = nil AND isFailed = NO")
        
        do {
            let checkpoints = try self.managedObjectContext.fetch(request)
            
            for checkpoint in checkpoints {
                self.searchPhotoForCheckpoint(checkpoint)
            }
        } catch {
            fatalError("Failed to query local objects")
        }
    }
    
    private func searchPhotoForCheckpoint(_ checkpoint: Checkpoint) {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "FlickrAPIKey") as? String else {
            fatalError("Missing Flickr API key")
        }
        
        let searchUrl = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&content_type=1&lat=\(checkpoint.latitude)&lon=\(checkpoint.longitude)&radius=0.06&radius_units=km&extras=url_l,url_o,url_m&per_page=1&page=1&format=json&nojsoncallback=1"
        
        guard let url = URL(string: searchUrl) else {
            assertionFailure("Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard error == nil else {
                if let error = error as NSError?, error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet {
                    // Try again later
                    return
                }
                
                checkpoint.isFailed = true
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                checkpoint.isFailed = true
                return
            }
            
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let object = json as? [String:Any],
                let photos = object["photos"] as? [String:Any],
                let photoList = photos["photo"] as? [[String:Any]],
                let photo = photoList.first,
                let photoUrl = (photo["url_l"] as? String) ?? (photo["url_o"] as? String) ?? (photo["url_m"] as? String) else {
                    checkpoint.isFailed = true
                    return
            }
            
            DispatchQueue.main.async {
                checkpoint.remoteUrl = photoUrl
            }
        }
        
        task.resume()
    }
 }
