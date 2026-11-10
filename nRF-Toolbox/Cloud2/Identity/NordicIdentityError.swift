//
//  NordicIdentityError.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 10/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

enum NordicIdentityError: LocalizedError {
    case cancelled
    case invalidCallback
    case stateMismatch
    case server(String)
    case invalidResponse
    case notSignedIn
    
    var errorDescription: String? {
        switch self {
        case .cancelled: "Sign in was cancelled."
        case .invalidCallback: "The sign in callback was invalid."
        case .stateMismatch: "The sign in response did not match the request."
        case .server(let message): message
        case .invalidResponse: "Unexpected response from the server."
        case .notSignedIn: "Sign in to myNordic first."
        }
    }
}
