//
//  QuickStartBoard.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 13/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

// MARK: - QuickStartBoard

enum QuickStartBoard {
    case nRF54L15
    case nRF54LM20
    case unknown

    init(hardwareRevision: String) {
        switch hardwareRevision.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)).lowercased() {
        case "nrf54lm20dk":
            self = .nRF54LM20
        case "nrf54l15":
            self = .nRF54L15
        default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .nRF54LM20:
            return "nRF54LM20DK"
        case .nRF54L15, .unknown:
            return "nRF54L15DK"
        }
    }

    var imageName: String {
        switch self {
        case .nRF54LM20:
            return "nrf54lm20dk"
        case .nRF54L15, .unknown:
            return "nrf54dk"
        }
    }
}
