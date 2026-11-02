//
//  NRFCloudViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

@MainActor
@Observable
final class NRFCloudViewModel {
    
    struct Grouping {
        let inRange: [ConnectedDevicesViewModel.ScanResult]
        let other: [ConnectedDevicesViewModel.ScanResult]
        let offline: [NRFCloudDevice]
        let inRangeCloudCount: Int
    }
    
    enum LoadState<Value: Equatable>: Equatable {
        case loading
        case loaded(Value)
        case failed(String)
    }
    
    private static let selectionKey = "nrfcloud.selection"
    
    let account = MyNordicAccountViewModel()
    
    private(set) var devices: [NRFCloudDevice] = []
    private(set) var crashStates: [String: LoadState<[NRFCloudCrash]>] = [:]
    private(set) var rebootStates: [String: LoadState<[NRFCloudReboot]>] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var selection: NRFCloudSelection?
    private(set) var organizations: [NRFCloudOrganization] = []
    private(set) var projects: [NRFCloudProject] = []
    private(set) var isLoadingProjects = false
    private(set) var projectsErrorMessage: String?
    
    var isConfigured: Bool {
        account.isSignedIn && selection != nil
    }
    
    @ObservationIgnored private var lastGroupingSignature = ""
    @ObservationIgnored private var token: NRFCloudToken?
    @ObservationIgnored private var didProvision = false
    
    private let service = NRFCloudService()
    private let log = NordicLog(category: "NRFCloudViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    init() {
        MyNordicKeychain.deleteLegacyAPIKey()
        selection = UserDefaults.standard.data(forKey: Self.selectionKey)
            .flatMap { try? JSONDecoder().decode(NRFCloudSelection.self, from: $0) }
    }
    
    func start() async {
        await account.restore()
        guard account.isSignedIn else { return }
        do {
            _ = try await accessToken()
        } catch {
            log.error("Preloading cloud token failed: \(error.localizedDescription)")
            return
        }
        async let devicesLoad: () = refresh()
        async let projectsLoad: () = loadOrganizations()
        _ = await (devicesLoad, projectsLoad)
    }
    
    func signIn() async {
        await account.signIn()
        guard account.isSignedIn else { return }
        resetData()
        await loadOrganizations()
        await refresh()
    }
    
    func signOut() {
        account.signOut()
        token = nil
        didProvision = false
        organizations = []
        projects = []
        resetData()
        select(nil)
    }
    
    func loadOrganizations() async {
        guard account.isSignedIn, !isLoadingProjects else { return }
        isLoadingProjects = true
        projectsErrorMessage = nil
        defer { isLoadingProjects = false }
        do {
            let loaded = try await authorized { try await service.listOrganizations(token: $0) }
            organizations = loaded
            let slug = selection?.organization ?? loaded.first?.slug
            if let slug {
                projects = try await authorized { try await service.listProjects(token: $0, organization: slug) }
                if selection == nil, projects.count == 1, let project = projects.first {
                    selectProject(organization: slug, project: project.slug)
                }
            }
        } catch {
            log.error("Loading organizations failed: \(error.localizedDescription)")
            projectsErrorMessage = error.localizedDescription
        }
    }
    
    func loadProjects(organization: String) async {
        isLoadingProjects = true
        projectsErrorMessage = nil
        defer { isLoadingProjects = false }
        do {
            projects = try await authorized { try await service.listProjects(token: $0, organization: organization) }
        } catch {
            log.error("Loading projects failed: \(error.localizedDescription)")
            projectsErrorMessage = error.localizedDescription
        }
    }
    
    func selectProject(organization: String, project: String) {
        let newSelection = NRFCloudSelection(organization: organization, project: project)
        guard newSelection != selection else { return }
        log.info("Selected project \(organization)/\(project)")
        resetData()
        select(newSelection)
        Task { await refresh() }
    }
    
    func refresh() async {
        guard let selection, account.isSignedIn, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await withAccess(selection) { try await service.listDevices(access: $0) }
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            log.error("Refreshing devices failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func addDevice(serial: String, hardwareVersion: String, nickname: String?) async throws {
        guard let selection else { throw NRFCloudError.notFound("no project selected") }
        try await withAccess(selection) {
            try await service.addDevice(access: $0, serial: serial, hardwareVersion: hardwareVersion, nickname: nickname)
        }
        await refresh()
    }
    
    func cloudDevice(matching identifiers: [String?]) -> NRFCloudDevice? {
        let keys = Set(identifiers.compactMap { $0?.trimmed.lowercased() }.filter { !$0.isEmpty })
        let match = devices.first { !$0.matchKeys.isDisjoint(with: keys) }
        log.info("Matching \(keys.sorted()) against cloud devices: \(match.map { "found \($0.id)" } ?? "no match")")
        return match
    }
    
    func loadCrashes(for device: NRFCloudDevice) async {
        guard let selection else { return }
        if case .loaded = crashStates[device.id] {} else {
            crashStates[device.id] = .loading
        }
        do {
            let crashes = try await withAccess(selection) { try await service.listCrashes(access: $0, serial: device.id) }
            crashStates[device.id] = .loaded(crashes.sorted { ($0.capturedDate ?? .distantPast) > ($1.capturedDate ?? .distantPast) })
        } catch {
            log.error("Loading crashes for \(device.id) failed: \(error.localizedDescription)")
            crashStates[device.id] = .failed(error.localizedDescription)
        }
    }
    
    func crashDetail(for crash: NRFCloudCrash) async throws -> NRFCloudCrashDetail {
        guard let selection else { throw NRFCloudError.notFound("no project selected") }
        return try await withAccess(selection) { try await service.crashDetail(access: $0, traceID: crash.id) }
    }
    
    func loadReboots(for device: NRFCloudDevice) async {
        guard let selection else { return }
        if case .loaded = rebootStates[device.id] {} else {
            rebootStates[device.id] = .loading
        }
        do {
            let reboots = try await withAccess(selection) { try await service.listReboots(access: $0, serial: device.id) }
            rebootStates[device.id] = .loaded(reboots.sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) })
        } catch {
            log.error("Loading reboots for \(device.id) failed: \(error.localizedDescription)")
            rebootStates[device.id] = .failed(error.localizedDescription)
        }
    }
    
    private func resetData() {
        devices = []
        crashStates = [:]
        rebootStates = [:]
        errorMessage = nil
    }
    
    private func select(_ newSelection: NRFCloudSelection?) {
        selection = newSelection
        let data = newSelection.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }
    
    private func withAccess<T>(_ selection: NRFCloudSelection, _ request: (NRFCloudAccess) async throws -> T) async throws -> T {
        try await authorized { try await request(NRFCloudAccess(token: $0, selection: selection)) }
    }
    
    private func authorized<T>(_ request: (String) async throws -> T) async throws -> T {
        do {
            return try await request(try await accessToken())
        } catch NRFCloudError.rejected(let status, _) where status == 401 {
            log.info("Memfault token rejected. Requesting a new one.")
            token = nil
            return try await request(try await accessToken())
        }
    }
    
    private func accessToken() async throws -> String {
        if let token, token.expiresAt.timeIntervalSinceNow > 60 {
            return token.value
        }
        let idToken = try await account.idToken()
        if !didProvision {
            try await service.provisionAccount(idToken: idToken)
            didProvision = true
        }
        let fresh = try await service.exchange(idToken: idToken)
        token = fresh
        return fresh.value
    }
    
    func group(_ scanned: [ConnectedDevicesViewModel.ScanResult]) -> Grouping {
        guard isConfigured, !devices.isEmpty else {
            return Grouping(inRange: [], other: scanned, offline: [], inRangeCloudCount: 0)
        }
        let cloudKeys = devices.reduce(into: Set<String>()) { $0.formUnion($1.matchKeys) }
        let scannedNames = Set(scanned.compactMap { $0.name?.trimmed.lowercased() })
        let inRange = scanned.filter { $0.name.map { cloudKeys.contains($0.trimmed.lowercased()) } ?? false }
        let other = scanned.filter { !inRange.contains($0) }
        let offline = devices.filter { $0.matchKeys.isDisjoint(with: scannedNames) }
        logGrouping(scanned: scanned, inRange: inRange, offline: offline)
        return Grouping(inRange: inRange, other: other, offline: offline,
                        inRangeCloudCount: devices.count - offline.count)
    }
    
    private func logGrouping(scanned: [ConnectedDevicesViewModel.ScanResult],
                             inRange: [ConnectedDevicesViewModel.ScanResult],
                             offline: [NRFCloudDevice]) {
        let scannedNames = scanned.map { $0.name ?? "<no name>" }.sorted()
        let signature = "\(scannedNames)|\(devices.map(\.id))"
        guard signature != lastGroupingSignature else { return }
        lastGroupingSignature = signature
        log.info("Cloud devices (\(devices.count)): \(devices.map { "\($0.id) [\($0.nickname ?? "no nickname")]" }.sorted().joined(separator: ", "))")
        log.info("Scanned names (\(scanned.count)): \(scannedNames.joined(separator: ", "))")
        log.info("Matched (\(inRange.count)): \(inRange.map { $0.name ?? "<no name>" }.joined(separator: ", "))")
        log.info("Offline (\(offline.count)): \(offline.map(\.id).joined(separator: ", "))")
    }
}
