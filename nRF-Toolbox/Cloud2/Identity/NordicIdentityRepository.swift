//
//  NordicIdentityRepository.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

@MainActor
@Observable
final class NordicIdentityRepository {

    private static let expirationMargin: TimeInterval = 60

    @ObservationIgnored private let service: NordicIdentityService
    @ObservationIgnored private let keychain = NordicIdentityKeychain()
    private var identity: NordicIdentity?

    init(service: NordicIdentityService = NordicIdentityService()) {
        self.service = service
    }

    var userName: String? { identity?.userName }
    var isSignedIn: Bool { userName != nil }
    
    func obtainIdentity() async throws -> NordicIdentity {
        if let restored = try await restore() {
            return restored
        }
        return try await signIn()
    }

    func signOut() {
        identity = nil
        keychain.deleteRefreshToken()
    }
}

private extension NordicIdentityRepository {

    func isValid(_ idToken: String) -> Bool {
        guard let expiration = Claims(jwt: idToken)?.expirationDate else { return false }
        return expiration.timeIntervalSinceNow > Self.expirationMargin
    }

    func restore() async throws -> NordicIdentity? {
        guard let refreshToken = identity?.refreshToken ?? keychain.loadRefreshToken() else { return nil }
        do {
            let refreshedIdentity = try await service.refreshNordicIdentity(refreshToken: refreshToken)
            store(identity: refreshedIdentity)
            return refreshedIdentity
        } catch NordicIdentityError.server(_) {
            identity = nil
            keychain.deleteRefreshToken()
            return nil
        }
    }

    func signIn() async throws -> NordicIdentity {
        let identity = try await service.signInToNordicIdentity()
        store(identity: identity)
        return identity
    }

    func store(identity: NordicIdentity) {
        self.identity = identity
        if let refreshToken = identity.refreshToken {
            keychain.save(refreshToken: refreshToken)
        }
    }
}
