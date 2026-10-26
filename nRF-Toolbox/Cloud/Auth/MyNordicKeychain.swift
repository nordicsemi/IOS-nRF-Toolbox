//
//  MyNordicKeychain.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import Security

struct MyNordicKeychain {
    
    private let service = "com.nordicsemi.nrf-toolbox.mynordic"
    private let account = "refresh-token"
    
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    
    func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func save(_ refreshToken: String) {
        delete()
        var request = query
        request[kSecValueData as String] = Data(refreshToken.utf8)
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(request as CFDictionary, nil)
    }
    
    func delete() {
        SecItemDelete(query as CFDictionary)
    }
    
    static func deleteLegacyAPIKey() {
        let legacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.nordicsemi.nrf-toolbox.nrfcloud",
            kSecAttrAccount as String: "credentials"
        ]
        SecItemDelete(legacy as CFDictionary)
    }
}
