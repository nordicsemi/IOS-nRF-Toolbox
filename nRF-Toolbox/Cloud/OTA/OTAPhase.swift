//
//  OTAPhase.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

enum OTAPhase: Hashable {
    case idle
    case checking
    case upToDate
    case available
    case downloading
    case updating
    case verifying
    case failed

    init(_ state: DeviceOTAViewModel.State) {
        self = switch state {
        case .idle: .idle
        case .checking: .checking
        case .upToDate: .upToDate
        case .available: .available
        case .downloading: .downloading
        case .updating: .updating
        case .verifying: .verifying
        case .failed: .failed
        }
    }

    var isWorking: Bool {
        switch self {
        case .checking, .downloading, .updating, .verifying: true
        default: false
        }
    }

    var icon: String {
        switch self {
        case .idle: "cpu"
        case .checking: "magnifyingglass"
        case .upToDate: "checkmark.circle.fill"
        case .available: "arrow.down.circle.fill"
        case .downloading: "icloud.and.arrow.down.fill"
        case .updating: "arrow.triangle.2.circlepath"
        case .verifying: "power"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .failed: Color.nordicRed
        case .idle: .secondary
        default: Color.universalAccentColor
        }
    }

    var title: String {
        switch self {
        case .idle: "Firmware"
        case .checking: "Checking for updates"
        case .upToDate: "Firmware is updated"
        case .available: "Update available"
        case .downloading: "Downloading"
        case .updating: "Updating firmware"
        case .verifying: "Finishing up"
        case .failed: "Something went wrong"
        }
    }

    var subtitle: String {
        switch self {
        case .idle: "Tap to look for a newer version"
        case .checking: "Looking for the latest release"
        case .upToDate: "You have the latest version"
        case .available: "A newer release is ready to install"
        case .downloading: "Keep the app open"
        case .updating: "Do not disconnect or close the app"
        case .verifying: "Confirming the installed version"
        case .failed: "Check your connection and try again"
        }
    }
}
