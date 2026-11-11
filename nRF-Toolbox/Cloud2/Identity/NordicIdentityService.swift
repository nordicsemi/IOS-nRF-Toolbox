//
//  NordicIdentityService.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 09/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import AuthenticationServices

struct NordicIdentityService {
    
    private static let clientID = "5b42d3f5-9af2-4d64-9cb1-00f85bf27da8"
    private static let source = "nrfconnectfordesktop"
    private static let redirectURI = "\(source)://my-nordic/auth/callback"
    private static let scopes = [
        "openid",
        "profile",
        "email",
        "offline_access",
        "https://graph.microsoft.com/User.Read"
    ]
    private static var scopeValue: String { scopes.joined(separator: " ") }
    
    private static let baseUrl = "https://nordicsemiextprod.ciamlogin.com"
    private static let tenantId = "1fb18d84-2f00-4d3e-a795-e45655386b44"
    private static let authorizeUrl = URL(string: "\(baseUrl)/\(tenantId)/oauth2/v2.0/authorize")!
    private static let tokenUrl = URL(string: "\(baseUrl)/\(tenantId)/oauth2/v2.0/token")!
    private static let graphMeURL = URL(string: "https://graph.microsoft.com/v1.0/me")!
    
    private let sessionRepository = AuthenticationSessionRepository()
    
    /// The process used is: The OIDC Authentication Flow
    func signInToNordicIdentity() async throws -> NordicIdentity {
        let pkce = PKCE()
        let csrfToken = UUID().uuidString
        let accessToken = try await requestAccessToken(pkce: pkce, csrfToken: csrfToken)
        let tokens = try await requestCloudTokens(pkce: pkce, accessToken: accessToken)
        let userName = try await requestUserName(accessToken: tokens.accessToken)
        
        return NordicIdentity(
            userName: userName,
            accessToken: tokens.accessToken,
            idToken: tokens.idToken,
            refreshToken: tokens.refreshToken
        )
    }
    
    // MARK: Access Token
    
    private func requestAccessToken(pkce: PKCE, csrfToken: String) async throws -> String {
        let url = getAuthorizeUrl(pkce: pkce, csrfToken: csrfToken)
        let accessTokenUrl = try await sessionRepository.requestAccessToken(url: url)
        return try parseAccessToken(from: accessTokenUrl, csrfToken: csrfToken)
    }
    
    private func getAuthorizeUrl(pkce: PKCE, csrfToken: String) -> URL {
        var components = URLComponents(url: Self.authorizeUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "scope", value: Self.scopeValue),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "login"),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "state", value: csrfToken),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "source", value: Self.source)
        ]
        return components.url!
    }
    
    private func parseAccessToken(from callbackURL: URL, csrfToken: String) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
  
        if let description = items.findValue("error_description") {
            throw NordicIdentityError.server(description)
        }
        guard items.findValue("state") == csrfToken else {
            throw NordicIdentityError.stateMismatch
        }
        guard let code = items.findValue("code") else {
            throw NordicIdentityError.invalidCallback
        }
        return code
    }
    
    // MARK: Cloud Token
    
    private func requestCloudTokens(pkce: PKCE, accessToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: MyNordicConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: accessToken),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_verifier", value: pkce.verifier),
            URLQueryItem(name: "scope", value: Self.scopeValue)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            return response
        } catch let error {
            throw NordicIdentityError.server("Token request failed.")
        }
    }
    
    // MARK: Name
    
    private func requestUserName(accessToken: String) async throws -> String {
        var request = URLRequest(url: Self.graphMeURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NordicIdentityError.invalidResponse
        }
        let user = try JSONDecoder().decode(GraphMeResponse.self, from: data)
        guard let name = user.displayName ?? user.userPrincipalName else {
            throw NordicIdentityError.invalidResponse // TODO: maybe check if those can be gotten from id token.
        }
        return name
    }
}

private extension [URLQueryItem] {
    
    func findValue(_ name: String) -> String? {
        first { $0.name == name }?.value
    }
}
