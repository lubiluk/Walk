//
//  LastLocationController.swift
//  Walk
//
//  Created by Paweł Gajewski on 15/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation

class LastLocationController: NSObject {
    enum State {
        case stopped
        case running
    }
    
    static let stateDidChangeNotification =
        NSNotification.Name(rawValue: "WalkControllerStateDidChangeNotification")
    static let lastLocationDidChangeNotification =
        NSNotification.Name(rawValue: "WalkControllerLastLocationDidChangeNotification")
    
    var state = State.stopped {
        didSet {
            NotificationCenter.default.post(name: LastLocationController.stateDidChangeNotification, object: self)
        }
    }
    
    var locationServicesEnabled: Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    var lastLocation: CLLocation? {
        didSet {
            NotificationCenter.default.post(name: LastLocationController.lastLocationDidChangeNotification, object: self)
        }
    }
    
    private let locationManager = CLLocationManager()
    
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
        state = .stopped
    }
}

extension LastLocationController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        guard let lastLocation = lastLocation else {
            self.lastLocation = location
            return
        }
        
        if location.distance(from: lastLocation) > 0 {
            self.lastLocation = location
        }
    }
}
