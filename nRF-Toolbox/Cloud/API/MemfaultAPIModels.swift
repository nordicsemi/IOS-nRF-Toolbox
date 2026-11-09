//
//  MemfaultAPIModels.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct MemfaultEnvelope<T: Decodable>: Decodable {
    
    let data: T
}

struct MemfaultPage<T: Decodable>: Decodable {
    
    let data: [T]
    let paging: Paging
    
    struct Paging: Decodable {
        
        let pageCount: Int
        
        enum CodingKeys: String, CodingKey {
            case pageCount = "page_count"
        }
    }
}

struct MemfaultTokenResponse: Decodable {
    
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct MemfaultReleaseSummary: Decodable {
    
    let version: String
}

struct MemfaultRelease: Decodable {
    
    let version: String
    let notes: String?
    let artifacts: [Artifact]
    
    struct Artifact: Decodable {
        
        let type: String
        let softwareType: String
        let hardwareVersion: Hardware
        let filename: String
        let url: String
        let md5: String
        let downloadable: Bool?
        
        enum CodingKeys: String, CodingKey {
            case type, filename, url, md5, downloadable
            case softwareType = "software_type"
            case hardwareVersion = "hardware_version"
        }
        
        struct Hardware: Decodable {
            
            let name: String
        }
    }
}
