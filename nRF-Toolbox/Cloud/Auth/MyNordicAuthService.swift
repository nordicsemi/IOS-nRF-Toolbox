//
//  MyNordicAuthService.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import AuthenticationServices
import Foundation


enum MyNordicAuthError: LocalizedError {
    case cancelled
    case invalidCallback
    case stateMismatch
    case server(String)
    case invalidResponse
    case notSignedIn
    
    var errorDescription: String? {
        switch self {
        case .cancelled: "Sign in was cancelled."
        case .invalidCallback: "The sign in callback was invalid."
        case .stateMismatch: "The sign in response did not match the request."
        case .server(let message): message
        case .invalidResponse: "Unexpected response from the server."
        case .notSignedIn: "Sign in to myNordic first."
        }
    }
}


@MainActor
final class MyNordicAuthService: NSObject {
    
    private var session: ASWebAuthenticationSession?
    
    
    func signIn() async throws -> MyNordicAccount {
        let pkce = PKCE()
        let state = UUID().uuidString
        let code = try await authorize(pkce: pkce, state: state)
        let tokens = try await exchange(code: code, verifier: pkce.verifier)
        return try await account(from: tokens)
    }
    
    
    func refresh(refreshToken: String) async throws -> MyNordicAccount {
        var request = tokenRequest()
        request.httpBody = form([
            URLQueryItem(name: "client_id", value: MyNordicConfiguration.clientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "scope", value: MyNordicConfiguration.scopes.joined(separator: " "))
        ])
        let tokens = try await send(request, fallbackRefreshToken: refreshToken)
        return try await account(from: tokens)
    }
    
    
    private func account(from tokens: Tokens) async throws -> MyNordicAccount {
        let claims = tokens.idToken.flatMap(IDTokenClaims.init)
        let userName = try? await fetchUserName(accessToken: tokens.accessToken)
        guard let name = userName ?? claims?.name ?? claims?.preferredUsername else {
            throw MyNordicAuthError.invalidResponse
        }
        return MyNordicAccount(userName: name, accessToken: tokens.accessToken, idToken: tokens.idToken,
                               refreshToken: tokens.refreshToken, claims: claims)
    }
    
    
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
    
    
    private func exchange(code: String, verifier: String) async throws -> Tokens {
        var request = tokenRequest()
        request.httpBody = form([
            URLQueryItem(name: "client_id", value: MyNordicConfiguration.clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: MyNordicConfiguration.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "scope", value: MyNordicConfiguration.scopes.joined(separator: " "))
        ])
        return try await send(request, fallbackRefreshToken: nil)
    }
    
    
    private func tokenRequest() -> URLRequest {
        var request = URLRequest(url: MyNordicConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    
    private func form(_ items: [URLQueryItem]) -> Data? {
        var body = URLComponents()
        body.queryItems = items
        return body.percentEncodedQuery?.data(using: .utf8)
    }
    
    
    private func send(_ request: URLRequest, fallbackRefreshToken: String?) async throws -> Tokens {
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let accessToken = response.accessToken else {
            throw MyNordicAuthError.server(response.errorDescription ?? "Token request failed.")
        }
        return Tokens(accessToken: accessToken, idToken: response.idToken,
                      refreshToken: response.refreshToken ?? fallbackRefreshToken)
    }
    
    
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


extension MyNordicAuthService: ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}


private struct TokenResponse: Decodable {
    
    let accessToken: String?
    let idToken: String?
    let refreshToken: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case errorDescription = "error_description"
    }
}

private struct Tokens {
    
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
}

private struct GraphUser: Decodable {
    
    let displayName: String?
    let userPrincipalName: String?
}
