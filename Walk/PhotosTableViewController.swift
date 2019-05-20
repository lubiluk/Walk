//
//  PhotosTableViewController.swift
//  Walk
//
//  Created by Paweł Gajewski on 15/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import UIKit
import CoreData

class PhotosTableViewController: UITableViewController {
    private let permissionController = PermissionController()
    private let checkpointController = CheckpointController()
    private let photoSearchController = PhotoSearchController()
    private let photoDownloadController = PhotoDownloadController()
    private var observers = [NSObjectProtocol]()
    
    var managedObjectContext: NSManagedObjectContext!
    
    lazy var fetchedResultsController: NSFetchedResultsController<Checkpoint> = {
        let request = NSFetchRequest<Checkpoint>(entityName: Checkpoint.entityName)
        request.predicate = NSPredicate(format: "localPath != nil")
        let sort = NSSortDescriptor(key: "date", ascending: false)
        request.sortDescriptors = [sort]
        
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        do {
            try controller.performFetch()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        
        return controller
    }()

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = view.bounds.width * 0.75 // 4:3 aspect
        
        updateViews()
        
        checkpointController.managedObjectContext = managedObjectContext
        photoSearchController.managedObjectContext = managedObjectContext
        photoDownloadController.managedObjectContext = managedObjectContext
        
        let controllerObserver = NotificationCenter.default.addObserver(forName: .CheckpointControllerStateDidChange, object: checkpointController, queue: .main, using: { _ in
            self.updateViews()
        })
        
        // Retry searches and downloads that may fail due to network problems
        let appObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [unowned self] _ in
            self.photoSearchController.retrySearches()
            self.photoDownloadController.retryDownloads()
        }
        
        observers = [controllerObserver, appObserver]
    }
    
    private func updateViews() {
        switch checkpointController.state {
        case .running:
            navigationItem.rightBarButtonItem?.title = "Stop"
        case .stopped:
            navigationItem.rightBarButtonItem?.title = "Start"
        }
    }
    
    private func showAuthorizationPopup() {
        let alert = UIAlertController(title: "Location Services",
                                      message: "You have disabled location services for this app. Pictures won't load until you turn it back on.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        alert.addAction(settingsAction)
        
        present(alert, animated: true)
    }
    
    private func askForPermissionIfNeeded() {
        switch permissionController.permission {
        case .notDetermined:
            permissionController.requestPermission()
        case .denied:
            showAuthorizationPopup()
        default:
            ()
        }
    }
    
    // MARK: - Actions

    @IBAction func toggleWalk(_ sender: Any) {
        switch checkpointController.state {
        case .stopped:
            askForPermissionIfNeeded()
            checkpointController.deleteAllCheckpoints()
            photoDownloadController.deleteAllPhotos()
            tableView.reloadData()
            
            checkpointController.startTracking()
            photoSearchController.startSearching()
            photoDownloadController.startDownloading()
        case .running:
            checkpointController.stopTracking()
            photoSearchController.stopSearching()
            photoDownloadController.stopDownloading()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections!.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = fetchedResultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        
        let sectionInfo = sections[section]
        
        return sectionInfo.numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhotoCell", for: indexPath) as! PhotoTableViewCell
        let checkpoint = fetchedResultsController.object(at: indexPath)
        
        if let path = checkpoint.localPath {
            cell.photoImageView.image = UIImage(contentsOfFile: path)
        } else {
            // Empty photo indicates error. In the future we could add an option to retry download of failed photos.
            cell.photoImageView.image = nil
        }
        
        return cell
    }
}

extension PhotosTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move:
            break
        case .update:
            break
        @unknown default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        @unknown default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
