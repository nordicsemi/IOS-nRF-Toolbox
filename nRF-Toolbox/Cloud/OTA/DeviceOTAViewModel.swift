//
//  DeviceOTAViewModel.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOSMcuManagerLibrary
import iOSOtaLibrary
import iOS_Common_Libraries

enum OTACheckError: LocalizedError {
    case projectKeyUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .projectKeyUnavailable(let reason):
            "The device could not provide its Memfault project key (\(reason)). Check that the firmware has a project key configured."
        }
    }
}

@MainActor
@Observable
final class DeviceOTAViewModel: NSObject {

    enum State {
        case idle
        case checking
        case upToDate
        case available(CatalogRelease)
        case downloading(CatalogRelease)
        case updating(step: String, progress: Double?)
        case verifying
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var installedVersion: String?
    private(set) var updatedFromVersion: String?
    private(set) var updatedToVersion: String?
    private(set) var lastCheckedDate: Date?

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .updating, .verifying: true
        default: false
        }
    }

    @ObservationIgnored private var transport: McuMgrBleTransport?
    @ObservationIgnored private var upgradeManager: FirmwareUpgradeManager?
    @ObservationIgnored private var upgradeController: FirmwareUpgradeController?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var pendingRelease: CatalogRelease?
    @ObservationIgnored private var currentPeripheral: UUID?
    @ObservationIgnored private weak var currentCloud: NRFCloudViewModel?
    @ObservationIgnored private let otaManager = OTAManager()
    @ObservationIgnored private let log = NordicLog(category: "DeviceOTAViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    func autoCheck(peripheral identifier: UUID, cloud: NRFCloudViewModel) {
        guard !isBusy, cloud.isConfigured else { return }
        if let last = lastCheckedDate, Date().timeIntervalSince(last) < 20 { return }
        checkForUpdate(peripheral: identifier, cloud: cloud)
    }

    func checkForUpdate(peripheral identifier: UUID, cloud: NRFCloudViewModel) {
        guard !isBusy else { return }
        currentPeripheral = identifier
        currentCloud = cloud
        state = .checking
        task = Task { [weak self] in
            await self?.performCheck(peripheral: identifier, cloud: cloud)
        }
    }

    func install(_ release: CatalogRelease) {
        guard !isBusy, let transport else { return }
        pendingRelease = release
        state = .downloading(release)
        task = Task { [weak self] in
            await self?.performInstall(release: release, transport: transport)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        upgradeController?.cancel()
        if case .updating = state {
            return
        }
        state = .idle
    }

    func reset() {
        guard !isBusy else { return }
        state = .idle
    }

    private func performCheck(peripheral identifier: UUID, cloud: NRFCloudViewModel) async {
        let transport = McuMgrBleTransport(identifier)
        self.transport = transport
        do {
            log.info("Reading device info and project key")
            let deviceInfo = try await otaManager.getDeviceInfoToken(via: transport)
            installedVersion = deviceInfo.currentVersion
            log.info("Installed firmware \(deviceInfo.currentVersion) (\(deviceInfo.softwareType), \(deviceInfo.hardwareVersion), serial \(deviceInfo.deviceSerialNumber))")
            guard let release = try await cloud.newestRelease(newerThan: deviceInfo.currentVersion,
                                                              hardwareVersion: deviceInfo.hardwareVersion,
                                                              softwareType: deviceInfo.softwareType) else {
                throw OTAManagerError.deviceIsUpToDate
            }
            try Task.checkCancellation()
            log.info("Release \(release.version) is available")
            lastCheckedDate = Date()
            state = .available(release)
        } catch OTAManagerError.deviceIsUpToDate {
            lastCheckedDate = Date()
            state = .upToDate
        } catch is CancellationError {
            state = .idle
        } catch {
            log.error("Checking for update failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    private func performInstall(release: CatalogRelease, transport: McuMgrBleTransport) async {
        do {
            let url = try await MemfaultReleaseCatalog.download(release)
            try Task.checkCancellation()
            let package = try McuMgrPackage(from: url)
            let manager = FirmwareUpgradeManager(transport: transport, delegate: self)
            manager.logDelegate = self
            upgradeManager = manager
            state = .updating(step: "Starting", progress: nil)
            manager.start(package: package)
        } catch is CancellationError {
            state = .idle
        } catch {
            log.error("Installing update failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    private func verifyAfterUpdate() async {
        guard let peripheral = currentPeripheral, let cloud = currentCloud else {
            state = .idle
            return
        }
        for attempt in 1...4 {
            try? await Task.sleep(for: .seconds(attempt == 1 ? 4 : 3))
            guard !Task.isCancelled else { return }
            state = .verifying
            await performCheck(peripheral: peripheral, cloud: cloud)
            if case .failed = state {
                log.info("Re-reading firmware version after the update failed (attempt \(attempt)). Retrying.")
                continue
            }
            return
        }
    }

    private func finish(_ newState: State) {
        upgradeManager = nil
        upgradeController = nil
        state = newState
    }
}

extension DeviceOTAViewModel: FirmwareUpgradeDelegate {

    nonisolated func upgradeDidStart(controller: FirmwareUpgradeController) {
        Task { @MainActor in
            upgradeController = controller
        }
    }

    nonisolated func upgradeStateDidChange(from previousState: FirmwareUpgradeState, to newState: FirmwareUpgradeState) {
        Task { @MainActor in
            guard case .updating(_, let progress) = state else { return }
            state = .updating(step: newState.description.capitalized, progress: newState == .upload ? progress : nil)
        }
    }

    nonisolated func upgradeDidComplete() {
        Task { @MainActor in
            updatedFromVersion = installedVersion
            updatedToVersion = pendingRelease?.version
            finish(.verifying)
            task = Task { [weak self] in
                await self?.verifyAfterUpdate()
            }
        }
    }

    nonisolated func upgradeDidFail(inState state: FirmwareUpgradeState, with error: Error) {
        Task { @MainActor in
            finish(.failed(error.localizedDescription))
        }
    }

    nonisolated func upgradeDidCancel(state: FirmwareUpgradeState) {
        Task { @MainActor in
            finish(.idle)
        }
    }

    nonisolated func uploadProgressDidChange(bytesSent: Int, imageSize: Int, timestamp: Date) {
        Task { @MainActor in
            guard case .updating(let step, _) = state, imageSize > 0 else { return }
            state = .updating(step: step, progress: Double(bytesSent) / Double(imageSize))
        }
    }
}

extension DeviceOTAViewModel: McuMgrLogDelegate {

    nonisolated func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
        let line = "[McuMgr \(category)] \(msg)"
        switch level {
        case .error, .warning:
            log.error("\(line)")
        default:
            log.info("\(line)")
        }
    }
}
