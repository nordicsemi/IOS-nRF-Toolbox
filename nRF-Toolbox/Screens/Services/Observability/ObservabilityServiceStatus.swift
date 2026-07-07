//
//  ObservabilityServiceStatus.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 07/07/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: ObservabilityServiceStatus

enum ObservabilityServiceStatus {
    case connecting
    case connected
    case authenticated
    case online
    case offline
    case unauthorized
    case pairingError
    case error(String)

    var title: String {
        switch self {
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .authenticated: "Authenticated"
        case .online: "Online"
        case .offline: "Offline"
        case .unauthorized: "Unauthorized"
        case .pairingError: "Pairing Error"
        case .error(let message): message
        }
    }

    var systemImage: String {
        switch self {
        case .online, .authenticated, .connected: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .offline: "circle.slash"
        case .unauthorized, .pairingError, .error: "exclamationmark.triangle.fill"
        }
    }
    
    var imageColor: Color {
        switch self {
        case .online, .authenticated, .connecting, .connected: .nordicGrass
        case .offline: .nordicMiddleGrey
        case .unauthorized, .pairingError, .error: .nordicRed
        }
    }
}
