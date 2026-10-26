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
    let nickname: String?
    
    var displayName: String {
        nickname.flatMap { $0.trimmed.isEmpty ? nil : $0 } ?? id
    }
    
    var matchKeys: Set<String> {
        Set([id, nickname].compactMap { $0?.trimmed.lowercased() }.filter { !$0.isEmpty })
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "device_serial"
        case nickname
    }
}
