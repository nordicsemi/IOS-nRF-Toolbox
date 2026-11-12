//
//  TokenResponse.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 10/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

internal struct TokenResponse: Decodable {
    
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case errorDescription = "error_description"
    }
}
