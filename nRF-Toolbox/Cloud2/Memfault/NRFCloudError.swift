//
//  NRFCloudError.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

enum NRFCloudError: LocalizedError {
    case rejected(status: Int, details: String)
    case notFound(String)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .rejected(let status, let details): "Access rejected (HTTP \(status)): \(details)"
        case .notFound(let message): "Not found: \(message)"
        case .http(let status): "Request failed (HTTP \(status))."
        }
    }
}
