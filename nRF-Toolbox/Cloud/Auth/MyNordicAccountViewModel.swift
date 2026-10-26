//
//  MyNordicAccountViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation


@MainActor
@Observable
final class MyNordicAccountViewModel {
    
    private(set) var account: MyNordicAccount?
    var userName: String? { account?.userName }
    private(set) var isSigningIn = false
    var errorMessage: String?
    
    private let service = MyNordicAuthService()
    
    func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            account = try await service.signIn()
        } catch MyNordicAuthError.cancelled {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        account = nil
    }
}
