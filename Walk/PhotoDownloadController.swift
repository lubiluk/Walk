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
    
    deinit {
        stopDownloading()
    }
    
    func startDownloading() {
        let center = NotificationCenter.default
        center.addObserver(forName: Notification.Name.NSManagedObjectContextObjectsDidChange, object: nil, queue: .main) { [unowned self] (notification) in
            let request = NSFetchRequest<Checkpoint>(entityName: "Checkpoint")
            request.predicate = NSPredicate(format: "isSearched = YES AND isDownloaded = NO")
            
            do {
                let checkpoints = try self.managedObjectContext.fetch(request)
                
                for checkpoint in checkpoints {
                    self.downloadPhotoForCheckpoint(checkpoint)
                }
            } catch {
                self.failWithError(.checkpoint)
            }
        }
    }
    
    func stopDownloading() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // A bit naive but in this app this there are no other download tasks
        URLSession.shared.getAllTasks { (tasks) in
            for task in tasks {
                if task is URLSessionDownloadTask {
                    task.cancel()
                }
            }
        }
    }
    
    enum DownloadError: Error {
        case request
        case responseStatus
        case jsonParsing
        case fileSaving
        case searchUrl
        case photoUrl
        case tempUrl
        case apiKey
        case checkpoint
        
        var description: String {
            switch self {
            case .request:
                return "Download request failed."
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
            case .checkpoint:
                return "Failed to fetch checkpoint."
            }
        }
    }
    
    private func failWithError(_ error: DownloadError, underlyingError: Error? = nil) {
        
    }
    
    private func downloadPhotoForCheckpoint(_ checkpoint: Checkpoint) {        
        guard let stringUrl = checkpoint.remoteUrl, let remoteUrl = URL(string: stringUrl) else {
            failWithError(.photoUrl)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: remoteUrl) { [weak self] (url, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            defer {
                // Indicate that the download has been performed no matter if successful
                DispatchQueue.main.async {
                    checkpoint.isDownloaded = true
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
            
            guard let url = url else {
                strongSelf.failWithError(.tempUrl)
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
                
                DispatchQueue.main.async {
                    checkpoint.localPath = savedUrl.path
                }
            } catch {
               strongSelf.failWithError(.fileSaving)
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
