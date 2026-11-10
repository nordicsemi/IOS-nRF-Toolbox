//
//  GraphMeResponse.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 10/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

internal struct GraphMeResponse: Decodable {
    
    let displayName: String?
    let userPrincipalName: String?
}
