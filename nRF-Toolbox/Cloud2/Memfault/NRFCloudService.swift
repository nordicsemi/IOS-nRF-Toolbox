//
//  nRFCloudRepository.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

struct NRFCloudService {

    private static let host = "api.memfault.com"
    private static let perPage = 100
    private static let maxPages = 5

    private let log = NordicLog.cloud("NRFCloudService")

    func provisionAccount(idToken: String) async throws {
        log.info("Provisioning Memfault account")
        _ = try await post(path: "/mynordic/me", token: idToken)
    }

    func getCloudToken(idToken: String) async throws -> NRFCloudToken {
        log.info("Exchanging myNordic ID token for a Memfault access token")
        let data = try await post(path: "/mynordic/token", token: idToken)
        let response = try JSONDecoder().decode(MemfaultTokenResponse.self, from: data)
        log.info("Received Memfault access token valid for \(response.expiresIn) s")
        return NRFCloudToken(
            value: response.accessToken,
            expiresAt: Date(timeIntervalSinceNow: TimeInterval(response.expiresIn))
        )
    }

    func listOrganizations(token: String) async throws -> [NRFCloudOrganization] {
        let data = try await get(path: "/api/v0/organizations", token: token)
        let organizations = try JSONDecoder().decode(MemfaultEnvelope<[NRFCloudOrganization]>.self, from: data).data
        log.info("Fetched \(organizations.count) organization(s)")
        return organizations
    }

    func listProjects(token: String, organization: String) async throws -> [NRFCloudProject] {
        let data = try await get(path: "/api/v0/organizations/\(organization)/projects", token: token)
        let projects = try JSONDecoder().decode(MemfaultEnvelope<[NRFCloudProject]>.self, from: data).data
        log.info("Fetched \(projects.count) project(s) for \(organization)")
        return projects
    }

    func listDevices(token: String, selection: NRFCloudSelection) async throws -> [NRFCloudDevice] {
        log.info("Listing devices for \(selection.organization)/\(selection.project)")
        let devices: [NRFCloudDevice] = try await fetchAll(token: token, selection: selection, resource: "devices")
        log.info("Fetched \(devices.count) device(s)")
        return devices
    }

    func addDevice(token: String, selection: NRFCloudSelection, serial: String, hardwareVersion: String, nickname: String?) async throws {
        log.info("Adding device \(serial) to \(selection.organization)/\(selection.project)")
        var body = ["device_serial": serial, "hardware_version": hardwareVersion]
        if let nickname { body["nickname"] = nickname }
        _ = try await post(path: selection.createPath("devices"), token: token, body: body)
    }

    func listCrashes(token: String, selection: NRFCloudSelection, serial: String) async throws -> [NRFCloudCrash] {
        log.info("Listing crashes for device \(serial)")
        let crashes: [NRFCloudCrash] = try await fetchAll(
            token: token, selection: selection,
            resource: "traces",
            query: [URLQueryItem(name: "device", value: serial)],
            maxPages: Self.maxPages
        )
        log.info("Fetched \(crashes.count) crash(es) for device \(serial)")
        return crashes
    }

    func listReboots(token: String, selection: NRFCloudSelection, serial: String) async throws -> [NRFCloudReboot] {
        log.info("Listing reboots for device \(serial)")
        let reboots: [NRFCloudReboot] = try await fetchAll(
            token: token, selection: selection,
            resource: "devices/\(serial)/reboots",
            maxPages: Self.maxPages
        )
        log.info("Fetched \(reboots.count) reboot(s) for device \(serial)")
        return reboots
    }

    func crashDetail(token: String, selection: NRFCloudSelection, traceID: Int) async throws -> NRFCloudCrashDetail {
        log.info("Loading crash detail \(traceID)")
        let data = try await get(path: selection.createPath("traces/\(traceID)"), token: token)
        let detail = try NRFCloudCrashDetail.decode(from: data)
        log.info("Crash \(traceID): \(detail.threads.count) thread(s), \(detail.logs.count) log line(s), \(detail.faultRegisters.count) fault register(s)")
        return detail
    }

    func newestRelease(
        token: String, selection: NRFCloudSelection,
        newerThan currentVersion: String,
        hardwareVersion: String,
        softwareType: String
    ) async throws -> CatalogRelease? {
        log.info("Listing releases for hardware \(hardwareVersion), newer than \(currentVersion)")
        let summaries: [MemfaultReleaseSummary] = try await fetchAll(
            token: token, selection: selection,
            resource: "releases",
            query: [URLQueryItem(name: "hardware_version", value: hardwareVersion)]
        )
        let newerVersions = summaries.map(\.version)
            .filter { MemfaultReleaseCatalog.isVersion($0, newerThan: currentVersion) }
            .sorted { MemfaultReleaseCatalog.isVersion($0, newerThan: $1) }
        log.info("Fetched \(summaries.count) release(s), \(newerVersions.count) newer than \(currentVersion)")
        for version in newerVersions {
            let release = try await loadRelease(token: token, selection: selection, version: version)
            if let match = try catalogRelease(from: release, hardwareVersion: hardwareVersion, softwareType: softwareType) {
                return match
            }
            log.info("Release \(version) has no \(softwareType)/\(hardwareVersion) firmware artifact")
        }
        return nil
    }

    func loadRelease(token: String, selection: NRFCloudSelection, version: String) async throws -> MemfaultRelease {
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? version
        let data = try await get(path: selection.createPath("releases/\(encoded)"), token: token)
        return try JSONDecoder().decode(MemfaultEnvelope<MemfaultRelease>.self, from: data).data
    }

    func catalogRelease(from release: MemfaultRelease, hardwareVersion: String, softwareType: String) throws -> CatalogRelease? {
        let artifact = release.artifacts.first {
            $0.type == "firmware"
            && $0.softwareType == softwareType
            && $0.hardwareVersion.name == hardwareVersion
            && $0.downloadable != false
        }
        guard let artifact else { return nil }
        guard let url = URL(string: artifact.url) else { throw MemfaultReleaseCatalogError.invalidArtifactURL }
        return CatalogRelease(
            version: release.version,
            notes: release.notes ?? "",
            filename: artifact.filename,
            url: url,
            md5: artifact.md5
        )
    }
}

private extension NRFCloudService {

    func get(path: String, query: [URLQueryItem] = [], token: String) async throws -> Data {
        try await send("GET", path: path, query: query, token: token)
    }

    func post(path: String, token: String, body: (any Encodable)? = nil) async throws -> Data {
        try await send("POST", path: path, token: token, body: body)
    }

    func fetchAll<T: Decodable>(
        token: String,
        selection: NRFCloudSelection,
        resource: String,
        query: [URLQueryItem] = [],
        maxPages: Int = .max
    ) async throws -> [T] {
        var items: [T] = []
        var page = 1
        var pageCount = 1
        repeat {
            let paging = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(Self.perPage))
            ]
            let data = try await get(path: selection.createPath(resource), query: query + paging, token: token)
            let result = try JSONDecoder().decode(MemfaultPage<T>.self, from: data)
            items.append(contentsOf: result.data)
            pageCount = result.paging.pageCount
            page += 1
        } while page <= pageCount && page <= maxPages
        return items
    }

    func send(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        token: String,
        body: (any Encodable)? = nil
    ) async throws -> Data {
        let request = try makeRequest(method, path: path, query: query, token: token, body: body)
        let (data, response) = try await execute(request)
        return try handleResponse(data, response, for: request)
    }

    func makeRequest(
        _ method: String,
        path: String,
        query: [URLQueryItem],
        token: String,
        body: (any Encodable)?
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw NRFCloudError.notFound("invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        log.debug("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        return try await URLSession.shared.data(for: request)
    }

    func handleResponse(_ data: Data, _ response: URLResponse, for request: URLRequest) throws -> Data {
        let path = request.url?.path ?? ""
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
}

private extension NRFCloudSelection {

    func createPath(_ resource: String) -> String {
        "/api/v0/organizations/\(organization)/projects/\(project)/\(resource)"
    }
}
