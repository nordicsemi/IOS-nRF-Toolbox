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

    var isSignedIn: Bool { repository.isSignedIn }
    var userName: String? { repository.userName }
    var errorMessage: String?

    private(set) var isSigningIn = false

    private let repository: NordicIdentityRepository
    private let log = NordicLog.cloud("NordicAccountViewModel")

    init(identity: NordicIdentityRepository) {
        self.repository = identity
    }

    func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            _ = try await repository.obtainIdentity()
        } catch NordicIdentityError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        repository.signOut()
    }
}
