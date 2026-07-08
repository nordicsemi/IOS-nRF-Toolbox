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
    case awaitingChunks
    case uploading
    case suspended(seconds: Int)
    case disconnected
    case unauthorized
    case pairingError
    case error(String)

    var title: String {
        switch self {
        case .connecting: "Connecting…"
        case .awaitingChunks: "Awaiting chunks…"
        case .uploading: "Uploading…"
        case .suspended(let seconds): "Suspended for \(seconds)s"
        case .disconnected: "Disconnected"
        case .unauthorized: "Unauthorized"
        case .pairingError: "Pairing Error"
        case .error(let message): message
        }
    }

    var systemImage: String {
        switch self {
        case .awaitingChunks: "hourglass"
        case .uploading: "arrow.up.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .suspended: "pause.circle.fill"
        case .disconnected: "circle.slash"
        case .unauthorized, .pairingError, .error: "exclamationmark.triangle.fill"
        }
    }

    var imageColor: Color {
        switch self {
        case .uploading, .connecting: .nordicGrass
        case .awaitingChunks: .nordicMiddleGrey
        case .suspended: .nordicSun
        case .disconnected: .nordicMiddleGrey
        case .unauthorized, .pairingError, .error: .nordicRed
        }
    }
}
