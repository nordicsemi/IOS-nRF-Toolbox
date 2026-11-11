//
//  nRFCloudRepository.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 11/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

@MainActor
final class nRFCloudRepository {

    private static let expirationMargin: TimeInterval = 60
    private static let selectionKey = "nrfcloud.selection"

    private let service: nRFCloudService
    private let identity: NordicIdentityRepository
    var selection: NRFCloudSelection? {
        didSet { persistSelection() }
    }

    private var cloudToken: NRFCloudToken?
    private var didProvision = false

    init(identity: NordicIdentityRepository, service: nRFCloudService = nRFCloudService()) {
        self.identity = identity
        self.service = service
        selection = Self.loadSelection()
    }

    func reset() {
        cloudToken = nil
        didProvision = false
    }

    func listOrganizations() async throws -> [NRFCloudOrganization] {
        let token = try await token()
        return try await service.listOrganizations(token: token)
    }

    func listProjects(organization: String) async throws -> [NRFCloudProject] {
        let token = try await token()
        return try await service.listProjects(token: token, organization: organization)
    }

    func listDevices() async throws -> [NRFCloudDevice] {
        let access = try await access()
        return try await service.listDevices(access: access)
    }

    func addDevice(serial: String, hardwareVersion: String, nickname: String?) async throws {
        let access = try await access()
        try await service.addDevice(access: access, serial: serial, hardwareVersion: hardwareVersion, nickname: nickname)
    }

    func listCrashes(serial: String) async throws -> [NRFCloudCrash] {
        let access = try await access()
        return try await service.listCrashes(access: access, serial: serial)
    }

    func listReboots(serial: String) async throws -> [NRFCloudReboot] {
        let access = try await access()
        return try await service.listReboots(access: access, serial: serial)
    }

    func crashDetail(traceID: Int) async throws -> NRFCloudCrashDetail {
        let access = try await access()
        return try await service.crashDetail(access: access, traceID: traceID)
    }

    func newestRelease(
        newerThan currentVersion: String,
        hardwareVersion: String,
        softwareType: String
    ) async throws -> CatalogRelease? {
        let access = try await access()
        return try await service.newestRelease(
            access: access,
            newerThan: currentVersion,
            hardwareVersion: hardwareVersion,
            softwareType: softwareType
        )
    }
    
    private static func loadSelection() -> NRFCloudSelection? {
        UserDefaults.standard.data(forKey: selectionKey)
            .flatMap { try? JSONDecoder().decode(NRFCloudSelection.self, from: $0) }
    }

    private func persistSelection() {
        let data = selection.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }

    private func access() async throws -> NRFCloudAccess {
        guard let selection else { throw NRFCloudError.notFound("no project selected") }
        return NRFCloudAccess(token: try await token(), selection: selection)
    }

    private func token() async throws -> String {
        if let cloudToken, cloudToken.expiresAt.timeIntervalSinceNow > Self.expirationMargin {
            return cloudToken.value
        }
        let idToken = try await identity.idToken()
        if !didProvision {
            try await service.provisionAccount(idToken: idToken)
            didProvision = true
        }
        let fresh = try await service.getCloudToken(idToken: idToken)
        cloudToken = fresh
        return fresh.value
    }
}
