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
        case available(LatestReleaseInfo)
        case downloading(LatestReleaseInfo)
        case updating(step: String, progress: Double?)
        case completed
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var installedVersion: String?

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .updating: true
        default: false
        }
    }

    @ObservationIgnored private var transport: McuMgrBleTransport?
    @ObservationIgnored private var upgradeManager: FirmwareUpgradeManager?
    @ObservationIgnored private var upgradeController: FirmwareUpgradeController?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let otaManager = OTAManager()
    @ObservationIgnored private let log = NordicLog(category: "DeviceOTAViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    func checkForUpdate(peripheral identifier: UUID) {
        guard !isBusy else { return }
        state = .checking
        task = Task { [weak self] in
            await self?.performCheck(peripheral: identifier)
        }
    }

    func install(_ release: LatestReleaseInfo) {
        guard !isBusy, let transport, let artifact = release.artifacts.first else { return }
        state = .downloading(release)
        task = Task { [weak self] in
            await self?.performInstall(artifact: artifact, transport: transport)
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

    private func performCheck(peripheral identifier: UUID) async {
        let transport = McuMgrBleTransport(identifier)
        self.transport = transport
        do {
            log.info("Reading device info and project key")
            let deviceInfo = try await otaManager.getDeviceInfoToken(via: transport)
            installedVersion = deviceInfo.currentVersion
            log.info("Installed firmware \(deviceInfo.currentVersion) (\(deviceInfo.softwareType), \(deviceInfo.hardwareVersion), serial \(deviceInfo.deviceSerialNumber))")
            let projectKey: ProjectKey
            do {
                projectKey = try await otaManager.getProjectKey(via: transport)
            } catch {
                log.error("Reading project key failed: \(error.localizedDescription)")
                throw OTACheckError.projectKeyUnavailable(error.localizedDescription)
            }
            let release = try await otaManager.getLatestReleaseInfo(deviceInfo: deviceInfo, projectKey: projectKey)
            try Task.checkCancellation()
            log.info("Release \(release.version) is available")
            state = .available(release)
        } catch OTAManagerError.deviceIsUpToDate {
            state = .upToDate
        } catch is CancellationError {
            state = .idle
        } catch {
            log.error("Checking for update failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    private func performInstall(artifact: ReleaseArtifact, transport: McuMgrBleTransport) async {
        do {
            let url = try await otaManager.download(artifact: artifact)
            try Task.checkCancellation()
            let package = try McuMgrPackage(from: url)
            let manager = FirmwareUpgradeManager(transport: transport, delegate: self)
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
            finish(.completed)
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
