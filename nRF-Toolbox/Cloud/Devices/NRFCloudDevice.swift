//
//  NRFCloudDevice.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudDevice: Identifiable, Decodable, Equatable {
    
    let id: String
    
    var displayName: String {
        id
    }
    
    var matchKey: String {
        id.trimmed.lowercased()
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "device_serial"
    }
}
