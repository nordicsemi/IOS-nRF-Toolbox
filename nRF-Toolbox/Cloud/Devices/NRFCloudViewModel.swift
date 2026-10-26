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
    
    private(set) var devices: [NRFCloudDevice] = []
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
        await refresh()
    }
    
    func removeCredentials() {
        log.info("Removing credentials")
        keychain.delete()
        credentials = nil
        devices = []
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
    
    func group(_ scanned: [ConnectedDevicesViewModel.ScanResult]) -> Grouping {
        guard isConfigured, !devices.isEmpty else {
            return Grouping(inRange: [], other: scanned, offline: [], inRangeCloudCount: 0)
        }
        let cloudKeys = Set(devices.map(\.matchKey))
        let scannedNames = Set(scanned.compactMap { $0.name?.trimmed.lowercased() })
        let inRange = scanned.filter { $0.name.map { cloudKeys.contains($0.trimmed.lowercased()) } ?? false }
        let other = scanned.filter { !inRange.contains($0) }
        let offline = devices.filter { !scannedNames.contains($0.matchKey) }
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
        log.info("Cloud serials (\(devices.count)): \(devices.map(\.id).sorted().joined(separator: ", "))")
        log.info("Scanned names (\(scanned.count)): \(scannedNames.joined(separator: ", "))")
        log.info("Matched (\(inRange.count)): \(inRange.map { $0.name ?? "<no name>" }.joined(separator: ", "))")
        log.info("Offline (\(offline.count)): \(offline.map(\.id).joined(separator: ", "))")
    }
}
