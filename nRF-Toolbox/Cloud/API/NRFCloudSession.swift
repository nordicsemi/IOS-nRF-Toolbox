//
//  NRFCloudSession.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

@MainActor
final class NRFCloudSession {
    
    private static let expirationMargin: TimeInterval = 60
    
    private let myNordic: MyNordicAccountViewModel
    private let service: NRFCloudService
    private let log = NordicLog.cloud("NRFCloudSession")
    private var cloudToken: NRFCloudToken?
    private var didProvision = false
    
    init(account: MyNordicAccountViewModel, service: NRFCloudService) {
        self.myNordic = account
        self.service = service
    }
    
    func reset() {
        cloudToken = nil
        didProvision = false
    }
    
    func accessToken() async throws -> String {
        if let cloudToken, cloudToken.expiresAt.timeIntervalSinceNow > Self.expirationMargin {
            return cloudToken.value
        }
        let idToken = try await myNordic.idToken()
        if !didProvision {
            try await service.provisionAccount(idToken: idToken)
            didProvision = true
        }
        let fresh = try await service.getCloudToken(idToken: idToken)
        cloudToken = fresh
        return fresh.value
    }
    
    func authorized<T>(_ request: (String) async throws -> T) async throws -> T {
        do {
            return try await request(try await accessToken())
        } catch NRFCloudError.rejected(let status, _) where status == 401 {
            log.info("Memfault token rejected. Requesting a new one.")
            cloudToken = nil
            return try await request(try await accessToken())
        }
    }
    
    func authorized<T>(
        for selection: NRFCloudSelection,
        _ request: (NRFCloudAccess) async throws -> T
    ) async throws -> T {
        try await authorized { try await request(NRFCloudAccess(token: $0, selection: selection)) }
    }
}
