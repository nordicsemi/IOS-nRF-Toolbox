//
//  MyNordicConfiguration.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

// MARK: - MyNordicConfiguration

enum MyNordicConfiguration {
    
    static let clientID = "5b42d3f5-9af2-4d64-9cb1-00f85bf27da8"
    static let callbackScheme = "nrfconnectfordesktop"
    static let redirectURI = "\(callbackScheme)://my-nordic/auth/callback"
    static let source = "nrfconnectfordesktop"
    
    static let scopes = [
        "openid",
        "profile",
        "email",
        "offline_access",
        "https://graph.microsoft.com/User.Read"
    ]
    
    static let tenantID = "1fb18d84-2f00-4d3e-a795-e45655386b44"
    static let authority = "https://nordicsemiextprod.ciamlogin.com/\(tenantID)"
    
    static let authorizeURL = URL(string: "\(authority)/oauth2/v2.0/authorize")!
    static let tokenURL = URL(string: "\(authority)/oauth2/v2.0/token")!
    static let graphMeURL = URL(string: "https://graph.microsoft.com/v1.0/me")!
}
