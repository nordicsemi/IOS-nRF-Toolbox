//
//  MyNordicAccount.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation


struct MyNordicAccount {
    
    let userName: String
    let accessToken: String
    let idToken: String?
    let claims: IDTokenClaims?
}


struct IDTokenClaims: Decodable {
    
    let name: String?
    let preferredUsername: String?
    let email: String?
    let subject: String?
    let objectID: String?
    
    enum CodingKeys: String, CodingKey {
        case name, email
        case preferredUsername = "preferred_username"
        case subject = "sub"
        case objectID = "oid"
    }
    
    init?(jwt: String) {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(IDTokenClaims.self, from: data) else { return nil }
        self = claims
    }
}
