//
//  MemfaultAPIModels.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

internal struct MemfaultEnvelope<T: Decodable>: Decodable {
    
    let data: T
}

internal struct MemfaultPage<T: Decodable>: Decodable {
    
    let data: [T]
    let paging: Paging
    
    struct Paging: Decodable {
        
        let pageCount: Int
        
        enum CodingKeys: String, CodingKey {
            case pageCount = "page_count"
        }
    }
}

internal struct MemfaultTokenResponse: Decodable {
    
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
