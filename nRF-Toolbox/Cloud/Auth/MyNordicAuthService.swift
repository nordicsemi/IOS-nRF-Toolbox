//
//  MyNordicAuthService.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import AuthenticationServices
import Foundation

// MARK: - MyNordicAuthError

enum MyNordicAuthError: LocalizedError {
    case cancelled
    case invalidCallback
    case stateMismatch
    case server(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .cancelled: "Sign in was cancelled."
        case .invalidCallback: "The sign in callback was invalid."
        case .stateMismatch: "The sign in response did not match the request."
        case .server(let message): message
        case .invalidResponse: "Unexpected response from the server."
        }
    }
}

// MARK: - MyNordicAuthService

@MainActor
final class MyNordicAuthService: NSObject {
    
    private var session: ASWebAuthenticationSession?
    
    // MARK: signIn
    
    func signIn() async throws -> String {
        let pkce = PKCE()
        let state = UUID().uuidString
        let code = try await authorize(pkce: pkce, state: state)
        let accessToken = try await exchange(code: code, verifier: pkce.verifier)
        return try await fetchUserName(accessToken: accessToken)
    }
    
    // MARK: authorize
    
    private func authorize(pkce: PKCE, state: String) async throws -> String {
        var components = URLComponents(url: MyNordicConfiguration.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: MyNordicConfiguration.clientID),
            URLQueryItem(name: "scope", value: MyNordicConfiguration.scopes.joined(separator: " ")),
            URLQueryItem(name: "redirect_uri", value: MyNordicConfiguration.redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "login"),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "source", value: MyNordicConfiguration.source)
        ]
        
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: MyNordicConfiguration.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: MyNordicAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? MyNordicAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
        session = nil
        
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let description = items.first(where: { $0.name == "error_description" })?.value {
            throw MyNordicAuthError.server(description)
        }
        guard items.first(where: { $0.name == "state" })?.value == state else {
            throw MyNordicAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw MyNordicAuthError.invalidCallback
        }
        return code
    }
    
    // MARK: exchange
    
    private func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: MyNordicConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: MyNordicConfiguration.clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: MyNordicConfiguration.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "scope", value: MyNordicConfiguration.scopes.joined(separator: " "))
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let token = response.accessToken else {
            throw MyNordicAuthError.server(response.errorDescription ?? "Token request failed.")
        }
        return token
    }
    
    // MARK: fetchUserName
    
    private func fetchUserName(accessToken: String) async throws -> String {
        var request = URLRequest(url: MyNordicConfiguration.graphMeURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw MyNordicAuthError.invalidResponse
        }
        let user = try JSONDecoder().decode(GraphUser.self, from: data)
        guard let name = user.displayName ?? user.userPrincipalName else {
            throw MyNordicAuthError.invalidResponse
        }
        return name
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension MyNordicAuthService: ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

// MARK: - Responses

private struct TokenResponse: Decodable {
    
    let accessToken: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case errorDescription = "error_description"
    }
}

private struct GraphUser: Decodable {
    
    let displayName: String?
    let userPrincipalName: String?
}
