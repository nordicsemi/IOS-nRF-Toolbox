//
//  NordicIdentityRepository.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

@MainActor
final class NordicIdentityRepository {

    private static let expirationMargin: TimeInterval = 60

    private let service: NordicIdentityService
    private let keychain = NordicIdentityKeychain()
    private var identity: NordicIdentity?
    private var identityTask: Task<NordicIdentity, Error>?

    init(service: NordicIdentityService = NordicIdentityService()) {
        self.service = service
    }

    var userName: String? { identity?.userName }

    func restoreSession() async throws -> Bool {
        try await restore() != nil
    }

    func signInInteractively() async throws {
        _ = try await signIn()
    }

    func signOut() {
        identity = nil
        keychain.deleteRefreshToken()
    }

    func idToken() async throws -> String {
        if let idToken = identity?.idToken, isValid(idToken) {
            return idToken
        }
        let current = try await obtainIdentity()
        guard let idToken = current.idToken else { throw NordicIdentityError.invalidResponse }
        return idToken
    }
}

private extension NordicIdentityRepository {

    func isValid(_ idToken: String) -> Bool {
        guard let expiration = Claims(jwt: idToken)?.expirationDate else { return false }
        return expiration.timeIntervalSinceNow > Self.expirationMargin
    }

    func obtainIdentity() async throws -> NordicIdentity {
        if let identityTask {
            return try await identityTask.value
        }
        let task = Task {
            if let restored = try await restore() {
                return restored
            }
            return try await signIn()
        }
        identityTask = task
        defer { identityTask = nil }
        return try await task.value
    }

    func restore() async throws -> NordicIdentity? {
        guard let refreshToken = identity?.refreshToken ?? keychain.loadRefreshToken() else { return nil }
        do {
            let refreshed = try await service.refreshNordicIdentity(refreshToken: refreshToken)
            store(refreshed)
            return refreshed
        } catch NordicIdentityError.server(_) {
            identity = nil
            keychain.deleteRefreshToken()
            return nil
        }
    }

    func signIn() async throws -> NordicIdentity {
        let signedIn = try await service.signInToNordicIdentity()
        store(signedIn)
        return signedIn
    }

    func store(_ newIdentity: NordicIdentity) {
        identity = newIdentity
        if let refreshToken = newIdentity.refreshToken {
            keychain.save(refreshToken: refreshToken)
        }
    }
}
