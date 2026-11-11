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
        return try await authorized { token in
            try await service.listOrganizations(token: token)
        }
    }

    func listProjects(organization: String) async throws -> [NRFCloudProject] {
        return try await authorized { token in
            try await service.listProjects(token: token, organization: organization)
        }
    }

    func listDevices() async throws -> [NRFCloudDevice] {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        return try await authorized { token in
            try await service.listDevices(token: token, selection: selection)
        }
    }

    func addDevice(serial: String, hardwareVersion: String, nickname: String?) async throws {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        try await authorized { token in
            try await service.addDevice(token: token, selection: selection, serial: serial, hardwareVersion: hardwareVersion, nickname: nickname)
        }
    }

    func listCrashes(serial: String) async throws -> [NRFCloudCrash] {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        return try await authorized { token in
            try await service.listCrashes(token: token, selection: selection, serial: serial)
        }
    }

    func listReboots(serial: String) async throws -> [NRFCloudReboot] {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        return try await authorized { token in
            try await service.listReboots(token: token, selection: selection, serial: serial)
        }
    }

    func crashDetail(traceID: Int) async throws -> NRFCloudCrashDetail {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        return try await authorized { token in
            try await service.crashDetail(token: token, selection: selection, traceID: traceID)
        }
    }

    func newestRelease(
        newerThan currentVersion: String,
        hardwareVersion: String,
        softwareType: String
    ) async throws -> CatalogRelease? {
        guard let selection else { throw NRFCloudError.notFound("No project selected.") }
        return try await authorized { token in
            try await service.newestRelease(
                token: token, selection: selection,
                newerThan: currentVersion,
                hardwareVersion: hardwareVersion,
                softwareType: softwareType
            )
        }
    }
    
    private static func loadSelection() -> NRFCloudSelection? {
        UserDefaults.standard.data(forKey: selectionKey)
            .flatMap { try? JSONDecoder().decode(NRFCloudSelection.self, from: $0) }
    }

    private func persistSelection() {
        let data = selection.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }

    private func authorized<T>(_ request: (String) async throws -> T) async throws -> T {
        do {
            return try await request(try await token())
        } catch NRFCloudError.rejected(let status, _) where status == 401 {
            cloudToken = nil
            return try await request(try await token())
        }
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
