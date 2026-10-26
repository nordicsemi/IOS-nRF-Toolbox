//
//  NRFCloudCredentials.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudCredentials: Codable, Equatable {
    
    var email: String
    var organization: String
    var project: String
    var apiKey: String
    
    var isComplete: Bool {
        ![email, organization, project, apiKey].contains { $0.trimmed.isEmpty }
    }
    
    var trimmedCopy: NRFCloudCredentials {
        NRFCloudCredentials(email: email.trimmed, organization: organization.trimmed,
                            project: project.trimmed, apiKey: apiKey.trimmed)
    }
}

extension String {
    
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
