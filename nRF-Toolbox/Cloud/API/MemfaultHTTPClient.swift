//
//  MemfaultHTTPClient.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

struct MemfaultHTTPClient {
    
    private static let host = "api.memfault.com"
    private static let perPage = 100
    
    private let log = NordicLog.cloud("MemfaultHTTPClient")
    
    func postMyNordic(path: String, idToken: String) async throws -> Data {
        var request = URLRequest(url: try Self.url(path: path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }
    
    func get(path: String, token: String) async throws -> Data {
        try await perform(authorizedRequest(url: Self.url(path: path), token: token))
    }
    
    func get(access: NRFCloudAccess, resource: String, query: [URLQueryItem] = []) async throws -> Data {
        let url = try Self.url(path: Self.projectPath(access: access, resource: resource), query: query)
        return try await perform(authorizedRequest(url: url, token: access.token))
    }
    
    func post(access: NRFCloudAccess, resource: String, body: some Encodable) async throws {
        let url = try Self.url(path: Self.projectPath(access: access, resource: resource))
        var request = authorizedRequest(url: url, token: access.token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        _ = try await perform(request)
    }
    
    func fetchAll<T: Decodable>(
        access: NRFCloudAccess,
        resource: String,
        query: [URLQueryItem] = [],
        maxPages: Int = .max
    ) async throws -> [T] {
        var items: [T] = []
        var page = 1
        var pageCount = 1
        repeat {
            let result: MemfaultPage<T> = try await fetchPage(access: access, resource: resource, query: query, page: page)
            items.append(contentsOf: result.data)
            pageCount = result.paging.pageCount
            page += 1
        } while page <= pageCount && page <= maxPages
        return items
    }
}

private extension MemfaultHTTPClient {
    
    static func projectPath(access: NRFCloudAccess, resource: String) -> String {
        "/api/v0/organizations/\(access.selection.organization)/projects/\(access.selection.project)/\(resource)"
    }
    
    static func url(path: String, query: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw NRFCloudError.notFound("invalid URL") }
        return url
    }
    
    func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    func fetchPage<T: Decodable>(
        access: NRFCloudAccess,
        resource: String,
        query: [URLQueryItem],
        page: Int
    ) async throws -> MemfaultPage<T> {
        let paging = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.perPage))
        ]
        let data = try await get(access: access, resource: resource, query: query + paging)
        logFirstItem(in: data, resource: resource, page: page)
        return try JSONDecoder().decode(MemfaultPage<T>.self, from: data)
    }
    
    func perform(_ request: URLRequest) async throws -> Data {
        let path = request.url?.path ?? ""
        log.debug("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
        log.info("Responded HTTP \(status) (\(data.count) bytes) from \(path)")
        log.debug("Body: \(body)")
        switch status {
        case 200..<300: return data
        case 401, 403: throw NRFCloudError.rejected(status: status, details: body)
        case 404: throw NRFCloudError.notFound(Self.apiMessage(in: data) ?? path)
        default: throw NRFCloudError.http(status)
        }
    }
    
    static func apiMessage(in data: Data) -> String? {
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (root?["error"] as? [String: Any])?["message"] as? String
    }
    
    func logFirstItem(in data: Data, resource: String, page: Int) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["data"] as? [[String: Any]]
        else {
            log.error("\(resource) page \(page): response is not in the expected {data: [...]} shape")
            return
        }
        
        log.info("\(resource) page \(page): \(items.count) item(s), top-level keys: \(root.keys.sorted().joined(separator: ", "))")
        guard let first = items.first,
              let json = try? JSONSerialization.data(withJSONObject: first, options: [.sortedKeys])
        else { return }
        log.info("\(resource) page \(page): first item fields: \(first.keys.sorted().joined(separator: ", "))")
        log.info("\(resource) page \(page): first item JSON: \(String(data: json, encoding: .utf8) ?? "")")
    }
}
