//
//  Claims.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

internal struct Claims: Decodable {
    
    let name: String?
    let preferredUsername: String?
    let email: String?
    let subject: String?
    let objectID: String?
    let expiration: TimeInterval?
    
    var expirationDate: Date? {
        expiration.map { Date(timeIntervalSince1970: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, email
        case expiration = "exp"
        case preferredUsername = "preferred_username"
        case subject = "sub"
        case objectID = "oid"
    }
    
    init?(jwt: String) {
        let parts = jwt.split(separator: ".") // jwt has 3 parts: Header.Payload.Signature
        guard parts.count == 3 else { return nil }
        var base64 = parts[1] // gets payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4) // base64 require a length that is a multiple of 4. Add padding characters "=" at the end if less.
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(Claims.self, from: data) else { return nil }
        self = claims
    }
}
