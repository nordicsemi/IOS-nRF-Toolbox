//
//  DeviceCrashesViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

@MainActor
@Observable
final class DeviceCrashesViewModel {
    
    private struct Request {
        let identifiers: [String?]
        let cloud: NRFCloudViewModel
        let reason: String
    }
    
    static let showsReboots = false
    private static let minimumInterval: Duration = .seconds(1)
    
    private(set) var cloudDevice: NRFCloudDevice?
    private(set) var lookupFinished = false
    private(set) var isLoading = false
    var selectedCrash: NRFCloudCrash?
    
    @ObservationIgnored private var didRequestOnFirstConnection = false
    @ObservationIgnored private var pending: Request?
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var lastStart: ContinuousClock.Instant?
    @ObservationIgnored private let log = NordicLog(category: "DeviceCrashesViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    func deviceConnected(identifiers: [String?], cloud: NRFCloudViewModel) {
        cloudDevice = cloud.cloudDevice(matching: identifiers)
        if let cloudDevice {
            lookupFinished = true
            if cloud.crashStates[cloudDevice.id] != nil {
                log.info("Reconnected. Crashes for \(cloudDevice.id) are already loaded.")
                return
            }
        }
        guard !didRequestOnFirstConnection else {
            log.info("Reconnected. Not reloading crashes.")
            return
        }
        didRequestOnFirstConnection = true
        request(identifiers: identifiers, cloud: cloud, reason: "first connection")
    }
    
    func request(identifiers: [String?], cloud: NRFCloudViewModel, reason: String) {
        if pending != nil {
            log.info("Crash reload (\(reason)) replaces the queued one.")
        } else if worker != nil {
            log.info("Crash reload (\(reason)) queued behind the running one.")
        }
        pending = Request(identifiers: identifiers, cloud: cloud, reason: reason)
        isLoading = true
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.drain()
        }
    }
    
    private func drain() async {
        while let request = pending {
            pending = nil
            await waitForMinimumInterval()
            lastStart = .now
            log.info("Reloading crashes (\(request.reason)).")
            await perform(request)
        }
        worker = nil
        isLoading = false
    }
    
    private func waitForMinimumInterval() async {
        guard let lastStart else { return }
        let elapsed = ContinuousClock.now - lastStart
        if elapsed < Self.minimumInterval {
            try? await Task.sleep(for: Self.minimumInterval - elapsed)
        }
    }
    
    private func perform(_ request: Request) async {
        let cloud = request.cloud
        await cloud.refresh()
        cloudDevice = cloud.cloudDevice(matching: request.identifiers)
        lookupFinished = true
        guard let cloudDevice else { return }
        async let crashes: Void = cloud.loadCrashes(for: cloudDevice)
        async let reboots: Void = loadRebootsIfShown(for: cloudDevice, cloud: cloud)
        _ = await (crashes, reboots)
    }
    
    private func loadRebootsIfShown(for device: NRFCloudDevice, cloud: NRFCloudViewModel) async {
        guard Self.showsReboots else { return }
        await cloud.loadReboots(for: device)
    }
}
