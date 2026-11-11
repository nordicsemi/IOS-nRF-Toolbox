//
//  NordicAccountViewModel.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

@MainActor
@Observable
final class NordicAccountViewModel {

    var isSignedIn: Bool { userName != nil }
    var errorMessage: String?

    private(set) var userName: String?
    private(set) var isSigningIn = false

    private let identity: NordicIdentityRepository
    private let log = NordicLog.cloud("NordicAccountViewModel")

    init(identity: NordicIdentityRepository) {
        self.identity = identity
    }

    func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await identity.signInInteractively()
            userName = identity.userName
        } catch NordicIdentityError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard !isSignedIn else { return }
        log.info("Restoring myNordic session")
        do {
            if try await identity.restoreSession() {
                userName = identity.userName
            }
        } catch {
            log.error("Restoring myNordic session failed: \(error.localizedDescription)")
        }
    }

    func signOut() {
        identity.signOut()
        userName = nil
    }
}
