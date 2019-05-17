//
//  PhotosTableViewController.swift
//  Walk
//
//  Created by Paweł Gajewski on 15/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import UIKit

class PhotosTableViewController: UITableViewController {
    private let permissionController = PermissionController()
    private let lastLocationController = LastLocationController()
    private let photoControlller = PhotoController()
    private var tokens: [NSObjectProtocol]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = view.bounds.width * 0.75 // 4:3 aspect

        let center = NotificationCenter.default
        let locationToken = center.addObserver(forName: LastLocationController.stateDidChangeNotification, object: lastLocationController, queue: .main) { [unowned self] (notification) in
            self.updateViews()
        }
        let lastLocationToken = center.addObserver(forName: LastLocationController.lastLocationDidChangeNotification, object: lastLocationController, queue: .main) { [unowned self] (notification) in
            guard let lastLocationController = notification.object as? LastLocationController,
                let location = lastLocationController.lastLocation else {
                    return
            }
            
            self.photoControlller.addPhotoForLocation(location)
        }
        let photoToken = center.addObserver(forName: PhotoController.photoDownloadDidFinishNotification, object: photoControlller, queue: .main) { [unowned self] (notification) in
            let indexPath = IndexPath(row: 0, section: 0)
            self.tableView.insertRows(at: [indexPath], with: .top)
        }
        
        tokens = [locationToken, lastLocationToken, photoToken]
        
        updateViews()
    }
    
    deinit {
        if let tokens = tokens {
            let center = NotificationCenter.default
            
            for token in tokens {
                center.removeObserver(token)
            }
        }
    }
    
    private func updateViews() {
        switch lastLocationController.state {
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
        switch lastLocationController.state {
        case .stopped:
            askForPermissionIfNeeded()
            photoControlller.deleteAllPhotos()
            lastLocationController.startTracking()
        case .running:
            lastLocationController.stopTracking()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return photoControlller.photos.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhotoCell", for: indexPath) as! PhotoTableViewCell
        let url = photoControlller.photos.reversed()[indexPath.row]
        
        cell.photoImageView.image = UIImage(contentsOfFile: url.relativePath)

        return cell
    }
}
