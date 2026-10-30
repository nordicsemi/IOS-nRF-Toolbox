//
//  ObservabilityViewModel.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Common_Libraries
import iOSOtaLibrary
import Network

// MARK: - ObservabilityViewModel

@Observable
final class ObservabilityViewModel: SupportedServiceViewModel {

    // MARK: Properties

    private(set) var status: ObservabilityServiceStatus = .connecting
    private(set) var chunksInfo = ObservabilityChunksInfo()
    private(set) var largeUploadsCompleted = 0

    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())

    // MARK: Private Properties

    private let observabilityManager = ObservabilityManager()
    private let peripheralIdentifier: UUID
    private var streamTask: Task<Void, Never>?
    private var suspensionTask: Task<Void, Never>?
    private let log = NordicLog(category: "ObservabilityViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.nordicsemi.nrf-toolbox.observability.path-monitor")
    private var isNetworkAvailable = true
    private var isBLEConnected = false

    private static let largeUploadChunkThreshold = 10
    private static let uploadBurstQuietPeriod: Duration = .seconds(5)
    private var burstUploadedCount = 0
    private var burstTask: Task<Void, Never>?

    // MARK: init

    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheralIdentifier = peripheral.peripheral.identifier
        log.debug("\(type(of: self)).\(#function)")
    }

    // MARK: deinit

    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }

    // MARK: description

    var description: String {
        "Observability"
    }

    // MARK: attachedView

    var attachedView: any View {
        ObservabilityView().environment(self)
    }

    // MARK: onConnect()

    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
    }

    // MARK: onInitialized()

    @MainActor
    func onInitialized() async {
        log.debug("\(type(of: self)).\(#function)")
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.handleNetworkAvailabilityChange(isAvailable)
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)

        let stream = observabilityManager.connectToDevice(peripheralIdentifier)
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await value in stream {
                    handle(value.event)
                }
            } catch {
                log.error("Observability stream error: \(error.localizedDescription)")
                handleStreamError(error)
            }
        }
    }

    // MARK: onDisconnect()

    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        pathMonitor.cancel()
        streamTask?.cancel()
        streamTask = nil
        suspensionTask?.cancel()
        suspensionTask = nil
        burstTask?.cancel()
        burstTask = nil
        burstUploadedCount = 0
        observabilityManager.disconnect(from: peripheralIdentifier)
        isBLEConnected = false
        status = .disconnected
    }

    // MARK: handle(_:)

    @MainActor
    private func handle(_ event: ObservabilityDeviceEvent) {
        log.debug("Observability event: \(event.description)")
        switch event {
        case .connected, .authenticated:
            isBLEConnected = true
            recomputeStatus()
        case .notifications:
            break
        case .online:
            // The phone's own `pathMonitor` is the source of truth for internet connectivity;
            // this SDK event's exact semantics don't reliably map to "has internet" or
            // "BLE connected", so it no longer drives status directly.
            break
        case .unauthorized:
            status = .unauthorized
        case .disconnected:
            isBLEConnected = false
            recomputeStatus()
        case .updatedChunks(let chunks):
            let uploadedBefore = chunksInfo.uploadedCount
            chunks.forEach { chunksInfo.processChunk($0) }
            recomputeStatus()
            if chunksInfo.uploadedCount > uploadedBefore {
                trackUploadBurst(newlyUploaded: chunksInfo.uploadedCount - uploadedBefore)
            }
        }
    }

    // MARK: recomputeStatus()

    // Single source of truth for `status`, derived from BLE connection state, pending chunks,
    // and internet availability — in that priority order. A dropped BLE connection always wins,
    // even if a suspension timer was already running.
    @MainActor
    private func recomputeStatus() {
        guard isBLEConnected else {
            suspensionTask?.cancel()
            suspensionTask = nil
            status = .disconnected
            return
        }
        guard chunksInfo.pendingCount > 0 else {
            suspensionTask?.cancel()
            suspensionTask = nil
            status = .awaitingChunks
            return
        }
        guard isNetworkAvailable else {
            // Already counting for this outage; don't reset the clock on every recompute.
            guard suspensionTask == nil else { return }
            startSuspension()
            return
        }
        if suspensionTask != nil {
            suspensionTask?.cancel()
            suspensionTask = nil
            // Internet just came back while chunks were pending; the library doesn't resume
            // uploads on its own, so kick it explicitly.
            try? observabilityManager.continuePendingUploads(for: peripheralIdentifier)
        }
        status = .uploading
    }

    // MARK: trackUploadBurst()

    @MainActor
    private func trackUploadBurst(newlyUploaded: Int) {
        burstUploadedCount += newlyUploaded
        burstTask?.cancel()
        burstTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.uploadBurstQuietPeriod)
                guard let self, !Task.isCancelled else { return }
                guard chunksInfo.pendingCount == 0 else { continue }
                finishUploadBurst()
                return
            }
        }
    }

    // MARK: finishUploadBurst()

    @MainActor
    private func finishUploadBurst() {
        let uploaded = burstUploadedCount
        burstUploadedCount = 0
        guard uploaded >= Self.largeUploadChunkThreshold else { return }
        log.info("Large upload completed (\(uploaded) chunks).")
        largeUploadsCompleted += 1
    }

    // MARK: startSuspension()

    @MainActor
    private func startSuspension() {
        let detectedAt = Date()
        suspensionTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                status = .suspended(seconds: Int(Date().timeIntervalSince(detectedAt)))
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    // MARK: handleNetworkAvailabilityChange(_:)

    @MainActor
    private func handleNetworkAvailabilityChange(_ isAvailable: Bool) {
        guard isAvailable != isNetworkAvailable else { return }
        isNetworkAvailable = isAvailable
        recomputeStatus()
    }

    @MainActor
    private func handleStreamError(_ error: Error) {
        switch error {
        case ObservabilityError.pairingError:
            status = .pairingError
        case ObservabilityError.peripheralNotConnected:
            isBLEConnected = false
            recomputeStatus()
        case is ObservabilityError:
            status = .error(error.localizedDescription)
        default:
            isBLEConnected = false
            recomputeStatus()
        }
    }
}
