//
//  DeviceCrashesViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

@MainActor
@Observable
final class DeviceCrashesViewModel {
    
    static let showsReboots = false
    
    private(set) var cloudDevice: NRFCloudDevice?
    private(set) var lookupFinished = false
    var selectedCrash: NRFCloudCrash?
    
    func load(identifiers: [String?], cloud: NRFCloudViewModel) async {
        await cloud.refresh()
        cloudDevice = cloud.cloudDevice(matching: identifiers)
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
