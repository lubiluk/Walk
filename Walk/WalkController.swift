//
//  WalkController.swift
//  Walk
//
//  Created by Paweł Gajewski on 15/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation

class WalkController: NSObject {
    enum State {
        case stopped
        case running
    }
    
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case granted
    }
    
    static let stateDidChangeNotification =
        NSNotification.Name(rawValue: "WalkControllerStateDidChangeNotification")
    static let authorizationStatusDidChangeNotification =
        NSNotification.Name(rawValue: "WalkControllerAuthorizationStatusDidChangeNotification")
    
    var state = State.stopped {
        didSet {
            NotificationCenter.default.post(name: WalkController.stateDidChangeNotification, object: self)
        }
    }
    
    var authorizationStatus: AuthorizationStatus {
        didSet {
            NotificationCenter.default.post(name: WalkController.authorizationStatusDidChangeNotification, object: self)
        }
    }
    
    let locationManager = CLLocationManager()
    
    override init() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .authorizedAlways:
            authorizationStatus = .granted
        default:
            authorizationStatus = .denied
        }
        
        super.init()
        locationManager.delegate = self
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        
    }
    
    func stopTracking() {
        
    }
}

extension WalkController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .authorizedAlways:
            authorizationStatus = .granted
        default:
            authorizationStatus = .denied
        }
    }
}
