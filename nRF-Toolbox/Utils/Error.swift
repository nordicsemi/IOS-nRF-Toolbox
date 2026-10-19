//
//  Error.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 10/12/24.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import Foundation

// MARK: - CriticalError

enum ServiceError: LocalizedError {
    case unknown
    case serviceDiscoveryFailed
    case timeout
    case noData
    case notificationsNotEnabled
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error has occurred."
        case .serviceDiscoveryFailed:
            return "Service discovery failed."
        case .timeout:
            return "Timeout has occured."
        case .noData:
            return "Ivalid data."
        case .notificationsNotEnabled:
            return "An error occurred while enabling notifications."
        }
    }
}

enum ServiceWarning: LocalizedError {
    case unknown
    case measurement
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "An unknown error has occurred"
        case .measurement:
            return "Error occured while reading measurement."
        }
    }
}
