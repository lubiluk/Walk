//
//  PhotoDownloadController.swift
//  Walk
//
//  Created by Paweł Gajewski on 19/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class PhotoDownloadController {
    var managedObjectContext: NSManagedObjectContext!
    
    private var observer: NSObjectProtocol?
    private var runningTasks = [Checkpoint:URLSessionDownloadTask]()
    
    deinit {
        stopDownloading()
    }
    
    func startDownloading() {
        let center = NotificationCenter.default
        center.addObserver(forName: Notification.Name.NSManagedObjectContextObjectsDidChange, object: nil, queue: .main) { [unowned self] (notification) in
            self.download()
        }
    }
    
    func stopDownloading() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        for task in runningTasks.values {
            task.cancel()
        }
    }
    
    func retryDownloads() {
        download()
    }
    
    private func download() {
        let request = NSFetchRequest<Checkpoint>(entityName: Checkpoint.entityName)
        request.predicate = NSPredicate(format: "remoteUrl != nil AND localBookmark = nil AND isFailed = NO")
        
        do {
            let checkpoints = try self.managedObjectContext.fetch(request)
            
            for checkpoint in checkpoints {
                self.downloadPhotoForCheckpoint(checkpoint)
            }
        } catch {
            fatalError("Failed to query local objects")
        }
    }

    private func downloadPhotoForCheckpoint(_ checkpoint: Checkpoint) {        
        guard let stringUrl = checkpoint.remoteUrl, let remoteUrl = URL(string: stringUrl) else {
            checkpoint.isFailed = true
            return
        }
        
        if runningTasks[checkpoint] != nil {
            return
        }
        
        let task = URLSession.shared.downloadTask(with: remoteUrl) { [weak self] (url, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            defer {
                strongSelf.runningTasks[checkpoint] = nil
            }
            
            if let error = error {
                if let error = error as NSError?, error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet {
                    // Network unavailable, let's try again later
                    return
                }
                
                checkpoint.isFailed = true
                return
            }
            
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                checkpoint.isFailed = true
                return
            }
            
            guard let url = url else {
                checkpoint.isFailed = true
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
                
                // Skip duplicates
                if !fileManager.fileExists(atPath: savedUrl.path) {
                    try fileManager.moveItem(at: url, to: savedUrl)
                }
                
                let bookmark = try savedUrl.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                DispatchQueue.main.async {
                    checkpoint.localBookmark = bookmark
                    
                    do {
                        try strongSelf.managedObjectContext.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                }
            } catch {
               checkpoint.isFailed = true
            }
        }
        
        runningTasks[checkpoint] = task
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
