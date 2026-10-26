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
    
    private(set) var devices: [NRFCloudDevice] = []
    private(set) var crashStates: [String: LoadState<[NRFCloudCrash]>] = [:]
    private(set) var rebootStates: [String: LoadState<[NRFCloudReboot]>] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var credentials: NRFCloudCredentials?
    
    var isConfigured: Bool {
        credentials != nil
    }
    
    @ObservationIgnored private var lastGroupingSignature = ""
    
    private let keychain = NRFCloudKeychain()
    private let service = NRFCloudService()
    private let log = NordicLog(category: "NRFCloudViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    init() {
        credentials = keychain.load()
    }
    
    func save(_ newCredentials: NRFCloudCredentials) async {
        let trimmed = newCredentials.trimmedCopy
        log.info("Saving credentials for \(trimmed.organization)/\(trimmed.project)")
        keychain.save(trimmed)
        credentials = trimmed
        devices = []
        crashStates = [:]
        rebootStates = [:]
        await refresh()
    }
    
    func removeCredentials() {
        log.info("Removing credentials")
        keychain.delete()
        credentials = nil
        devices = []
        crashStates = [:]
        rebootStates = [:]
        errorMessage = nil
    }
    
    func refresh() async {
        guard let credentials, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await service.listDevices(credentials: credentials)
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            log.error("Refreshing devices failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func cloudDevice(matching identifiers: [String?]) -> NRFCloudDevice? {
        let keys = Set(identifiers.compactMap { $0?.trimmed.lowercased() }.filter { !$0.isEmpty })
        let match = devices.first { !$0.matchKeys.isDisjoint(with: keys) }
        log.info("Matching \(keys.sorted()) against cloud devices: \(match.map { "found \($0.id)" } ?? "no match")")
        return match
    }
    
    func loadCrashes(for device: NRFCloudDevice) async {
        guard let credentials else { return }
        if case .loaded = crashStates[device.id] {} else {
            crashStates[device.id] = .loading
        }
        do {
            let crashes = try await service.listCrashes(credentials: credentials, serial: device.id)
            crashStates[device.id] = .loaded(crashes.sorted { ($0.capturedDate ?? .distantPast) > ($1.capturedDate ?? .distantPast) })
        } catch {
            log.error("Loading crashes for \(device.id) failed: \(error.localizedDescription)")
            crashStates[device.id] = .failed(error.localizedDescription)
        }
    }
    
    func loadReboots(for device: NRFCloudDevice) async {
        guard let credentials else { return }
        if case .loaded = rebootStates[device.id] {} else {
            rebootStates[device.id] = .loading
        }
        do {
            let reboots = try await service.listReboots(credentials: credentials, serial: device.id)
            rebootStates[device.id] = .loaded(reboots.sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) })
        } catch {
            log.error("Loading reboots for \(device.id) failed: \(error.localizedDescription)")
            rebootStates[device.id] = .failed(error.localizedDescription)
        }
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
