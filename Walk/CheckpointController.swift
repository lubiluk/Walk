//
//  CheckpointController.swift
//  Walk
//
//  Created by Paweł Gajewski on 15/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

extension Notification.Name {
    static let CheckpointControllerStateDidChange = Notification.Name("CheckpointControllerStateDidChange")
}

class CheckpointController: NSObject {
    enum State {
        case stopped
        case running
    }
    
    var state = State.stopped {
        didSet {
            NotificationCenter.default.post(name: .CheckpointControllerStateDidChange, object: self)
        }
    }
    
    var locationServicesEnabled: Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    var managedObjectContext: NSManagedObjectContext!
    
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation? {
        didSet {
            guard let location = lastLocation else {
                return
            }
            
            DispatchQueue.main.async {
                let checkpoint = NSEntityDescription.insertNewObject(forEntityName: "Checkpoint", into: self.managedObjectContext) as! Checkpoint
                
                checkpoint.date = Date()
                checkpoint.latitude = location.coordinate.latitude
                checkpoint.longitude = location.coordinate.longitude
            }
        }
    }
    
    override init() {
        super.init()
        
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 100.0  // In meters.
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
    }
    
    func startTracking() {
        if (!locationServicesEnabled) {
            assertionFailure("Don't start tracking when location services are disabled")
            return
        }
        
        locationManager.startUpdatingLocation()
        state = .running
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        lastLocation = nil
        state = .stopped
    }
    
    func deleteAllCheckpoints() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Checkpoint")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedObjectContext.execute(deleteRequest)
        } catch {
            // TODO: handle the error
        }
    }
}

extension CheckpointController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        if location.timestamp.timeIntervalSinceNow > 60 {
            // Drop too old location
            return
        }
        
        guard let lastLocation = lastLocation else {
            // If it's the first location take it as it is
            self.lastLocation = location
            return
        }
        
        // Locations must be distict
        if location.distance(from: lastLocation) > 80 {
            self.lastLocation = location
        }
    }
}