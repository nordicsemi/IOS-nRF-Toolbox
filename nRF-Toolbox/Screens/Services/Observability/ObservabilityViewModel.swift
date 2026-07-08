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

    @MainActor
    func onConnect() async {
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
        case .updatedChunk(let chunk):
            chunksInfo.processChunk(chunk)
            recomputeStatus()
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
        if case ObservabilityError.pairingError = error {
            status = .pairingError
        } else {
            status = .error(error.localizedDescription)
        }
    }
}
