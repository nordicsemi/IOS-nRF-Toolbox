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
    
    let account: NordicAccountViewModel
    
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
    
    private let repository: NRFCloudRepository
    private let log = NordicLog.cloud("NRFCloudViewModel")
    
    init() {
        let identity = NordicIdentityRepository()
        account = NordicAccountViewModel(identity: identity)
        repository = NRFCloudRepository(identity: identity)
        selection = repository.selection
    }
    
    func start() async {
        await account.restore()
        guard account.isSignedIn else { return }
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
        repository.reset()
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
            let loaded = try await repository.listOrganizations()
            organizations = loaded
            let slug = selection?.organization ?? loaded.first?.slug
            if let slug {
                projects = try await repository.listProjects(organization: slug)
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
            projects = try await repository.listProjects(organization: organization)
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
        guard account.isSignedIn, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await repository.listDevices()
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            log.error("Refreshing devices failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func addDevice(serial: String, hardwareVersion: String, nickname: String?) async throws {
        try await repository.addDevice(serial: serial, hardwareVersion: hardwareVersion, nickname: nickname)
        await refresh()
    }
    
    func cloudDevice(matching identifiers: [String?]) -> NRFCloudDevice? {
        let keys = Set(identifiers.compactMap { $0?.trimmed.lowercased() }.filter { !$0.isEmpty })
        let match = devices.first { !$0.matchKeys.isDisjoint(with: keys) }
        log.info("Matching \(keys.sorted()) against cloud devices: \(match.map { "found \($0.id)" } ?? "no match")")
        return match
    }
    
    func newestRelease(newerThan currentVersion: String, hardwareVersion: String, softwareType: String) async throws -> CatalogRelease? {
        guard selection != nil, account.isSignedIn else { throw MemfaultReleaseCatalogError.notSignedIn }
        return try await repository.newestRelease(newerThan: currentVersion,
                                                  hardwareVersion: hardwareVersion, softwareType: softwareType)
    }
    
    func loadCrashes(for device: NRFCloudDevice) async {
        Self.markLoading(&crashStates, deviceID: device.id)
        crashStates[device.id] = await loadState(kind: "crashes", deviceID: device.id) {
            let crashes = try await self.repository.listCrashes(serial: device.id)
            return crashes.sorted { ($0.capturedDate ?? .distantPast) > ($1.capturedDate ?? .distantPast) }
        }
    }
    
    func crashDetail(for crash: NRFCloudCrash) async throws -> NRFCloudCrashDetail {
        try await repository.crashDetail(traceID: crash.id)
    }
    
    func loadReboots(for device: NRFCloudDevice) async {
        Self.markLoading(&rebootStates, deviceID: device.id)
        rebootStates[device.id] = await loadState(kind: "reboots", deviceID: device.id) {
            let reboots = try await self.repository.listReboots(serial: device.id)
            return reboots.sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }
        }
    }
    
    private static func markLoading<Item: Equatable>(_ states: inout [String: LoadState<[Item]>], deviceID: String) {
        if case .loaded = states[deviceID] { return }
        states[deviceID] = .loading
    }
    
    private func loadState<Item: Equatable>(
        kind: String,
        deviceID: String,
        _ fetch: () async throws -> [Item]
    ) async -> LoadState<[Item]> {
        do {
            return .loaded(try await fetch())
        } catch {
            log.error("Loading \(kind) for \(deviceID) failed: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
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
        repository.selection = newSelection
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
