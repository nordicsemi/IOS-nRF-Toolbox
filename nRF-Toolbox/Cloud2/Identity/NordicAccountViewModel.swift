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

    var isSignedIn: Bool { identity.isSignedIn }
    var userName: String? { identity.userName }
    var errorMessage: String?

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
        } catch NordicIdentityError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard !isSignedIn else { return }
        log.info("Restoring myNordic session")
        do {
            _ = try await identity.restoreSession()
        } catch {
            log.error("Restoring myNordic session failed: \(error.localizedDescription)")
        }
    }

    func signOut() {
        identity.signOut()
    }
}
