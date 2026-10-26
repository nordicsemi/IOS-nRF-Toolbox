//
//  NRFCloudKeychain.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import Security

struct NRFCloudKeychain {
    
    private let service = "com.nordicsemi.nrf-toolbox.nrfcloud"
    private let account = "credentials"
    
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    
    func load() -> NRFCloudCredentials? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(NRFCloudCredentials.self, from: data)
    }
    
    func save(_ credentials: NRFCloudCredentials) {
        delete()
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        var request = query
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(request as CFDictionary, nil)
    }
    
    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
