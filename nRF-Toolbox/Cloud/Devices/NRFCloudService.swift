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
        case .rejected(let status, let details): "Credentials rejected (HTTP \(status)): \(details)"
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
    
    func listDevices(credentials: NRFCloudCredentials) async throws -> [NRFCloudDevice] {
        log.info("Listing devices for \(credentials.organization)/\(credentials.project), key length: \(credentials.apiKey.count)")
        let devices: [NRFCloudDevice] = try await fetchAll(credentials: credentials, resource: "devices", query: [])
        log.info("Fetched \(devices.count) device(s)")
        return devices
    }
    
    func listCrashes(credentials: NRFCloudCredentials, serial: String) async throws -> [NRFCloudCrash] {
        log.info("Listing crashes for device \(serial)")
        let crashes: [NRFCloudCrash] = try await fetchAll(credentials: credentials, resource: "traces",
                                                          query: [URLQueryItem(name: "device", value: serial)],
                                                          maxPages: Self.maxPages)
        log.info("Fetched \(crashes.count) crash(es) for device \(serial)")
        return crashes
    }
    
    func listReboots(credentials: NRFCloudCredentials, serial: String) async throws -> [NRFCloudReboot] {
        log.info("Listing reboots for device \(serial)")
        let reboots: [NRFCloudReboot] = try await fetchAll(credentials: credentials, resource: "devices/\(serial)/reboots",
                                                           query: [], maxPages: Self.maxPages)
        log.info("Fetched \(reboots.count) reboot(s) for device \(serial)")
        return reboots
    }
    
    private func fetchAll<T: Decodable>(credentials: NRFCloudCredentials, resource: String,
                                        query: [URLQueryItem], maxPages: Int = .max) async throws -> [T] {
        var items: [T] = []
        var page = 1
        var pageCount = 1
        repeat {
            let result: Page<T> = try await fetchPage(credentials: credentials, resource: resource,
                                                       query: query, page: page)
            items.append(contentsOf: result.data)
            pageCount = result.paging.pageCount
            page += 1
        } while page <= pageCount && page <= maxPages
        return items
    }
    
    private func fetchPage<T: Decodable>(credentials: NRFCloudCredentials, resource: String,
                                         query: [URLQueryItem], page: Int) async throws -> Page<T> {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/api/v0/organizations/\(credentials.organization)/projects/\(credentials.project)/\(resource)"
        components.queryItems = query + [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.perPage))
        ]
        guard let url = components.url else { throw NRFCloudError.notFound("invalid URL") }
        
        let basic = Data("\(credentials.email):\(credentials.apiKey)".utf8).base64EncodedString()
        var request = URLRequest(url: url)
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        
        log.debug("GET \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
        log.info("Responded HTTP \(status): \(body)")
        switch status {
        case 200:
            logFirstItem(in: data, resource: resource, page: page)
            return try JSONDecoder().decode(Page<T>.self, from: data)
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
