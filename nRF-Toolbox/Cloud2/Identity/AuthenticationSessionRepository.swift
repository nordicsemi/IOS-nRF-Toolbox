//
//  AuthenticationSessionRepository.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 10/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import ObjectiveC
import AuthenticationServices

internal class AuthenticationSessionRepository : NSObject, ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    
    func requestAccessToken(url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: NordicIdentityService.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: NordicIdentityError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? NordicIdentityError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }
}
