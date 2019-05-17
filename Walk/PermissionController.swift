//
//  PermissionController.swift
//  Walk
//
//  Created by Paweł Gajewski on 16/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation
import CoreLocation

class PermissionController: NSObject {
    enum Permission {
        case notDetermined
        case denied
        case granted
    }
    
    static let permissionDidChangeNotification =
        NSNotification.Name(rawValue: "PermissionControllerPermissionDidChangeNotification")
    
    var permission: Permission {
        didSet {
            NotificationCenter.default.post(name: PermissionController.permissionDidChangeNotification, object: self)
        }
    }
    
    private let locationManager = CLLocationManager()
    
    override init() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            permission = .notDetermined
        case .authorizedAlways:
            permission = .granted
        default:
            permission = .denied
        }
        
        super.init()
        
        locationManager.delegate = self
    }
    
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }
}

extension PermissionController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            permission = .notDetermined
        case .authorizedAlways:
            permission = .granted
        default:
            permission = .denied
        }
    }
}
