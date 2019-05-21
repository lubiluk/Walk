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
                let checkpoint = Checkpoint.insertIntoContext(self.managedObjectContext)
                
                checkpoint.date = Date()
                checkpoint.latitude = location.coordinate.latitude
                checkpoint.longitude = location.coordinate.longitude
                
                do {
                    try self.managedObjectContext.save()
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        }
    }
    
    private let debouncer = Debouncer(delay: 3.0)
    
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
        do {
            try Checkpoint.deleteAllFromContext(managedObjectContext)
        } catch {
            fatalError("Failed to delete local objects")
        }
    }
}

extension CheckpointController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        if location.timestamp.timeIntervalSinceNow > 10 {
            // Drop too old location
            return
        }
        
        // An attempt to let the location settle down before using it
        debouncer.schedule { [unowned self] in
            self.lastLocation = location
        }
    }
}
