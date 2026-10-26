//
//  MyNordicAccountViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries


@MainActor
@Observable
final class MyNordicAccountViewModel {
    
    private static let expirationMargin: TimeInterval = 60
    
    private(set) var account: MyNordicAccount?
    var userName: String? { account?.userName }
    var isSignedIn: Bool { account != nil }
    private(set) var isSigningIn = false
    var errorMessage: String?
    
    private let service = MyNordicAuthService()
    private let keychain = MyNordicKeychain()
    private let log = NordicLog(category: "MyNordicAccountViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            adopt(try await service.signIn())
        } catch MyNordicAuthError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func restore() async {
        guard account == nil, let refreshToken = keychain.load() else { return }
        log.info("Restoring myNordic session")
        do {
            adopt(try await service.refresh(refreshToken: refreshToken))
        } catch {
            log.error("Restoring myNordic session failed: \(error.localizedDescription)")
        }
    }
    
    func idToken() async throws -> String {
        guard let account else { throw MyNordicAuthError.notSignedIn }
        if let idToken = account.idToken,
           let expiration = account.claims?.expirationDate,
           expiration.timeIntervalSinceNow > Self.expirationMargin {
            return idToken
        }
        guard let refreshToken = account.refreshToken else { throw MyNordicAuthError.notSignedIn }
        log.info("Refreshing myNordic ID token")
        let refreshed = try await service.refresh(refreshToken: refreshToken)
        adopt(refreshed)
        guard let idToken = refreshed.idToken else { throw MyNordicAuthError.invalidResponse }
        return idToken
    }
    
    func signOut() {
        account = nil
        keychain.delete()
    }
    
    private func adopt(_ newAccount: MyNordicAccount) {
        account = newAccount
        if let refreshToken = newAccount.refreshToken {
            keychain.save(refreshToken)
        }
    }
}
