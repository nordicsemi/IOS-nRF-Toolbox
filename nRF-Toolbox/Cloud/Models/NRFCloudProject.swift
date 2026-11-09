//
//  NRFCloudProject.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudSelection: Codable, Equatable {
    
    var organization: String
    var project: String
}

struct NRFCloudAccess {
    
    let token: String
    let selection: NRFCloudSelection
}

struct NRFCloudToken {
    
    let value: String
    let expiresAt: Date
}

struct NRFCloudOrganization: Decodable, Identifiable, Hashable {
    
    let id: Int
    let name: String
    let slug: String
}

struct NRFCloudProject: Decodable, Identifiable, Hashable {
    
    let id: Int
    let name: String
    let slug: String
}
