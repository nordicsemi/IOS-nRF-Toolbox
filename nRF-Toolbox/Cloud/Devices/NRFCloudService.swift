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
    case notFound
    case http(Int)
    
    var errorDescription: String? {
        switch self {
        case .rejected(let status, let details): "Credentials rejected (HTTP \(status)): \(details)"
        case .notFound: "Project not found. Check the organization and project slugs."
        case .http(let status): "Request failed (HTTP \(status))."
        }
    }
}

struct NRFCloudService {
    
    private static let host = "api.memfault.com"
    private static let perPage = 100
    
    private let log = NordicLog(category: "NRFCloudService", subsystem: "com.nordicsemi.nrf-toolbox")
    
    func listDevices(credentials: NRFCloudCredentials) async throws -> [NRFCloudDevice] {
        log.info("Listing devices for \(credentials.organization)/\(credentials.project), key length: \(credentials.apiKey.count)")
        var devices: [NRFCloudDevice] = []
        var page = 1
        var pageCount = 1
        repeat {
            let result = try await fetchPage(credentials: credentials, page: page)
            devices.append(contentsOf: result.data)
            pageCount = result.paging.pageCount
            page += 1
        } while page <= pageCount
        log.info("Fetched \(devices.count) device(s)")
        return devices
    }
    
    private func fetchPage(credentials: NRFCloudCredentials, page: Int) async throws -> Page {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/api/v0/organizations/\(credentials.organization)/projects/\(credentials.project)/devices"
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.perPage))
        ]
        guard let url = components.url else { throw NRFCloudError.notFound }
        
        let basic = Data("\(credentials.email):\(credentials.apiKey)".utf8).base64EncodedString()
        var request = URLRequest(url: url)
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        
        log.debug("GET \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
        log.info("Responded HTTP \(status): \(body)")
        switch status {
        case 200: return try JSONDecoder().decode(Page.self, from: data)
        case 401, 403: throw NRFCloudError.rejected(status: status, details: body)
        case 404: throw NRFCloudError.notFound
        default: throw NRFCloudError.http(status)
        }
    }
}

private struct Page: Decodable {
    
    let data: [NRFCloudDevice]
    let paging: Paging
}

private struct Paging: Decodable {
    
    let pageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case pageCount = "page_count"
    }
}
