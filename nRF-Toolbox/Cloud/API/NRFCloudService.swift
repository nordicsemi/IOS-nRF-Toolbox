//
//  NRFCloudService.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

struct NRFCloudService {

    private static let maxPages = 5

    private let client = MemfaultHTTPClient()
    private let log = NordicLog.cloud("NRFCloudService")

    func provisionAccount(idToken: String) async throws {
        log.info("Provisioning Memfault account")
        _ = try await client.postMyNordic(path: "/mynordic/me", idToken: idToken)
    }

    func getCloudToken(idToken: String) async throws -> NRFCloudToken {
        log.info("Exchanging myNordic ID token for a Memfault access token")
        let data = try await client.postMyNordic(path: "/mynordic/token", idToken: idToken)
        let response = try JSONDecoder().decode(MemfaultTokenResponse.self, from: data)
        log.info("Received Memfault access token valid for \(response.expiresIn) s")
        return NRFCloudToken(value: response.accessToken, expiresAt: Date(timeIntervalSinceNow: TimeInterval(response.expiresIn)))
    }

    func listOrganizations(token: String) async throws -> [NRFCloudOrganization] {
        let data = try await client.get(path: "/api/v0/organizations", token: token)
        let organizations = try JSONDecoder().decode(MemfaultEnvelope<[NRFCloudOrganization]>.self, from: data).data
        log.info("Fetched \(organizations.count) organization(s)")
        return organizations
    }

    func listProjects(token: String, organization: String) async throws -> [NRFCloudProject] {
        let data = try await client.get(path: "/api/v0/organizations/\(organization)/projects", token: token)
        let projects = try JSONDecoder().decode(MemfaultEnvelope<[NRFCloudProject]>.self, from: data).data
        log.info("Fetched \(projects.count) project(s) for \(organization)")
        return projects
    }

    func listDevices(access: NRFCloudAccess) async throws -> [NRFCloudDevice] {
        log.info("Listing devices for \(access.selection.organization)/\(access.selection.project)")
        let devices: [NRFCloudDevice] = try await client.fetchAll(access: access, resource: "devices")
        log.info("Fetched \(devices.count) device(s)")
        return devices
    }

    func addDevice(access: NRFCloudAccess, serial: String, hardwareVersion: String, nickname: String?) async throws {
        log.info("Adding device \(serial) to \(access.selection.organization)/\(access.selection.project)")
        var body = ["device_serial": serial, "hardware_version": hardwareVersion]
        if let nickname { body["nickname"] = nickname }
        try await client.post(access: access, resource: "devices", body: body)
    }

    func listCrashes(access: NRFCloudAccess, serial: String) async throws -> [NRFCloudCrash] {
        log.info("Listing crashes for device \(serial)")
        let crashes: [NRFCloudCrash] = try await client.fetchAll(
            access: access,
            resource: "traces",
            query: [URLQueryItem(name: "device", value: serial)],
            maxPages: Self.maxPages
        )
        log.info("Fetched \(crashes.count) crash(es) for device \(serial)")
        return crashes
    }

    func listReboots(access: NRFCloudAccess, serial: String) async throws -> [NRFCloudReboot] {
        log.info("Listing reboots for device \(serial)")
        let reboots: [NRFCloudReboot] = try await client.fetchAll(
            access: access,
            resource: "devices/\(serial)/reboots",
            maxPages: Self.maxPages
        )
        log.info("Fetched \(reboots.count) reboot(s) for device \(serial)")
        return reboots
    }

    func crashDetail(access: NRFCloudAccess, traceID: Int) async throws -> NRFCloudCrashDetail {
        log.info("Loading crash detail \(traceID)")
        let data = try await client.get(access: access, resource: "traces/\(traceID)")
        let detail = try NRFCloudCrashDetail.decode(from: data)
        log.info("Crash \(traceID): \(detail.threads.count) thread(s), \(detail.logs.count) log line(s), \(detail.faultRegisters.count) fault register(s)")
        return detail
    }

    func newestRelease(
        access: NRFCloudAccess,
        newerThan currentVersion: String,
        hardwareVersion: String,
        softwareType: String
    ) async throws -> CatalogRelease? {
        log.info("Listing releases for hardware \(hardwareVersion), newer than \(currentVersion)")
        let summaries: [MemfaultReleaseSummary] = try await client.fetchAll(
            access: access,
            resource: "releases",
            query: [URLQueryItem(name: "hardware_version", value: hardwareVersion)]
        )
        let newerVersions = summaries.map(\.version)
            .filter { MemfaultReleaseCatalog.isVersion($0, newerThan: currentVersion) }
            .sorted { MemfaultReleaseCatalog.isVersion($0, newerThan: $1) }
        log.info("Fetched \(summaries.count) release(s), \(newerVersions.count) newer than \(currentVersion)")
        for version in newerVersions {
            let release = try await loadRelease(access: access, version: version)
            if let match = try catalogRelease(from: release, hardwareVersion: hardwareVersion, softwareType: softwareType) {
                return match
            }
            log.info("Release \(version) has no \(softwareType)/\(hardwareVersion) firmware artifact")
        }
        return nil
    }
    
    func loadRelease(access: NRFCloudAccess, version: String) async throws -> MemfaultRelease {
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? version
        let data = try await client.get(access: access, resource: "releases/\(encoded)")
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
