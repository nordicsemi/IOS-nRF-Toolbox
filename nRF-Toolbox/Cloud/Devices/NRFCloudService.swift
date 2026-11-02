//
//  NRFCloudService.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

enum NRFCloudError: LocalizedError {
    case rejected(status: Int, details: String)
    case notFound(String)
    case http(Int)
    
    var errorDescription: String? {
        switch self {
        case .rejected(let status, let details): "Access rejected (HTTP \(status)): \(details)"
        case .notFound(let message): "Not found: \(message)"
        case .http(let status): "Request failed (HTTP \(status))."
        }
    }
}

struct NRFCloudService {
    
    private static let host = "api.memfault.com"
    private static let perPage = 100
    private static let maxPages = 5
    
    private let log = NordicLog(category: "NRFCloudService", subsystem: "com.nordicsemi.nrf-toolbox")
    
    func provisionAccount(idToken: String) async throws {
        log.info("Provisioning Memfault account")
        _ = try await perform(Self.myNordicRequest(path: "/mynordic/me", idToken: idToken))
    }
    
    func exchange(idToken: String) async throws -> NRFCloudToken {
        log.info("Exchanging myNordic ID token for a Memfault access token")
        let data = try await perform(Self.myNordicRequest(path: "/mynordic/token", idToken: idToken))
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        log.info("Received Memfault access token valid for \(response.expiresIn) s")
        return NRFCloudToken(value: response.accessToken, expiresAt: Date(timeIntervalSinceNow: TimeInterval(response.expiresIn)))
    }
    
    func listOrganizations(token: String) async throws -> [NRFCloudOrganization] {
        let page: DataEnvelope<[NRFCloudOrganization]> = try await decode(path: "/api/v0/organizations", token: token)
        log.info("Fetched \(page.data.count) organization(s)")
        return page.data
    }
    
    func listProjects(token: String, organization: String) async throws -> [NRFCloudProject] {
        let page: DataEnvelope<[NRFCloudProject]> = try await decode(path: "/api/v0/organizations/\(organization)/projects", token: token)
        log.info("Fetched \(page.data.count) project(s) for \(organization)")
        return page.data
    }
    
    func listDevices(access: NRFCloudAccess) async throws -> [NRFCloudDevice] {
        log.info("Listing devices for \(access.selection.organization)/\(access.selection.project)")
        let devices: [NRFCloudDevice] = try await fetchAll(access: access, resource: "devices", query: [])
        log.info("Fetched \(devices.count) device(s)")
        return devices
    }
    
    func addDevice(access: NRFCloudAccess, serial: String, hardwareVersion: String, nickname: String?) async throws {
        log.info("Adding device \(serial) to \(access.selection.organization)/\(access.selection.project)")
        var body: [String: String] = ["device_serial": serial, "hardware_version": hardwareVersion]
        if let nickname { body["nickname"] = nickname }
        let url = try projectURL(access: access, resource: "devices", query: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(access.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        _ = try await perform(request)
    }
    
    func listCrashes(access: NRFCloudAccess, serial: String) async throws -> [NRFCloudCrash] {
        log.info("Listing crashes for device \(serial)")
        let crashes: [NRFCloudCrash] = try await fetchAll(access: access, resource: "traces",
                                                          query: [URLQueryItem(name: "device", value: serial)],
                                                          maxPages: Self.maxPages)
        log.info("Fetched \(crashes.count) crash(es) for device \(serial)")
        return crashes
    }
    
    func listReboots(access: NRFCloudAccess, serial: String) async throws -> [NRFCloudReboot] {
        log.info("Listing reboots for device \(serial)")
        let reboots: [NRFCloudReboot] = try await fetchAll(access: access, resource: "devices/\(serial)/reboots",
                                                           query: [], maxPages: Self.maxPages)
        log.info("Fetched \(reboots.count) reboot(s) for device \(serial)")
        return reboots
    }
    
    func crashDetail(access: NRFCloudAccess, traceID: Int) async throws -> NRFCloudCrashDetail {
        log.info("Loading crash detail \(traceID)")
        let data = try await send(access: access, resource: "traces/\(traceID)", query: [])
        let detail = try NRFCloudCrashDetail.decode(from: data)
        log.info("Crash \(traceID): \(detail.threads.count) thread(s), \(detail.logs.count) log line(s), \(detail.faultRegisters.count) fault register(s)")
        return detail
    }
    
    private func decode<T: Decodable>(path: String, token: String) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = path
        guard let url = components.url else { throw NRFCloudError.notFound("invalid URL") }
        return try JSONDecoder().decode(T.self, from: try await get(url: url, token: token))
    }
    
    private static func myNordicRequest(path: String, idToken: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://\(host)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func fetchAll<T: Decodable>(access: NRFCloudAccess, resource: String,
                                        query: [URLQueryItem], maxPages: Int = .max) async throws -> [T] {
        var items: [T] = []
        var page = 1
        var pageCount = 1
        repeat {
            let result: Page<T> = try await fetchPage(access: access, resource: resource,
                                                       query: query, page: page)
            items.append(contentsOf: result.data)
            pageCount = result.paging.pageCount
            page += 1
        } while page <= pageCount && page <= maxPages
        return items
    }
    
    private func fetchPage<T: Decodable>(access: NRFCloudAccess, resource: String,
                                         query: [URLQueryItem], page: Int) async throws -> Page<T> {
        let paging = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.perPage))
        ]
        let data = try await send(access: access, resource: resource, query: query + paging)
        logFirstItem(in: data, resource: resource, page: page)
        return try JSONDecoder().decode(Page<T>.self, from: data)
    }
    
    private func send(access: NRFCloudAccess, resource: String, query: [URLQueryItem]) async throws -> Data {
        let url = try projectURL(access: access, resource: resource, query: query)
        return try await get(url: url, token: access.token)
    }
    
    private func projectURL(access: NRFCloudAccess, resource: String, query: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/api/v0/organizations/\(access.selection.organization)/projects/\(access.selection.project)/\(resource)"
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw NRFCloudError.notFound("invalid URL") }
        return url
    }
    
    private func get(url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }
    
    private func perform(_ request: URLRequest) async throws -> Data {
        let url = request.url!
        log.debug("\(request.httpMethod ?? "GET") \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
        log.info("Responded HTTP \(status) (\(data.count) bytes) from \(url.path)")
        log.debug("Body: \(body)")
        switch status {
        case 200..<300: return data
        case 401, 403: throw NRFCloudError.rejected(status: status, details: body)
        case 404: throw NRFCloudError.notFound(Self.apiMessage(in: data) ?? url.path)
        default: throw NRFCloudError.http(status)
        }
    }
}

extension NRFCloudService {
    
    fileprivate static func apiMessage(in data: Data) -> String? {
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (root?["error"] as? [String: Any])?["message"] as? String
    }
    
    fileprivate func logFirstItem(in data: Data, resource: String, page: Int) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["data"] as? [[String: Any]] else {
            log.error("\(resource) page \(page): response is not in the expected {data: [...]} shape")
            return
        }
        log.info("\(resource) page \(page): \(items.count) item(s), top-level keys: \(root.keys.sorted().joined(separator: ", "))")
        guard let first = items.first,
              let json = try? JSONSerialization.data(withJSONObject: first, options: [.sortedKeys]) else { return }
        log.info("\(resource) page \(page): first item fields: \(first.keys.sorted().joined(separator: ", "))")
        log.info("\(resource) page \(page): first item JSON: \(String(data: json, encoding: .utf8) ?? "")")
    }
}

private struct DataEnvelope<T: Decodable>: Decodable {
    
    let data: T
}

private struct TokenResponse: Decodable {
    
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct Page<T: Decodable>: Decodable {
    
    let data: [T]
    let paging: Paging
}

private struct Paging: Decodable {
    
    let pageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case pageCount = "page_count"
    }
}
