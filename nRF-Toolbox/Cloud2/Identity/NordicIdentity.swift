//
//  NordicIdentity.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 10/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

struct NordicIdentity {
    
    let userName: String
    let accessToken: String // Used for getting an user name.
    let idToken: String // Used for getting a cloud token.
    let refreshToken: String?
}
