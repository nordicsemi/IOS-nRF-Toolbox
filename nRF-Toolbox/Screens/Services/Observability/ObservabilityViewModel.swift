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

// MARK: - CBUUID

extension CBMUUID {
    /// Memfault Diagnostic Service.
    static let memfaultDiagnosticService = CBMUUID(string: "54220000-F6A5-4007-A371-722F4EBD8436")
}

// MARK: - ObservabilityViewModel

@Observable
final class ObservabilityViewModel: SupportedServiceViewModel {

    // MARK: Properties

    private(set) var status: ObservabilityServiceStatus = .connecting
    private(set) var pendingChunksCount: Int = 0
    private(set) var pendingBytesCount: Int = 0
    private(set) var uploadedChunksCount: Int = 0
    private(set) var uploadedBytesCount: Int = 0

    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())

    // MARK: Private Properties

    private let observabilityManager = ObservabilityManager()
    private let peripheralIdentifier: UUID
    private var streamTask: Task<Void, Never>?
    private var pendingChunkSizes: [UInt8: Int] = [:]
    private let log = NordicLog(category: "ObservabilityViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

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
        streamTask?.cancel()
        streamTask = nil
        observabilityManager.disconnect(from: peripheralIdentifier)
    }

    // MARK: handle(_:)

    @MainActor
    private func handle(_ event: ObservabilityDeviceEvent) {
        log.debug("Observability event: \(event.description)")
        switch event {
        case .connected:
            status = .connected
        case .authenticated:
            status = .authenticated
        case .notifications:
            break
        case .online(let isOnline):
            status = isOnline ? .online : .offline
        case .unauthorized:
            status = .unauthorized
        case .disconnected:
            status = .offline
        case .updatedChunk(let chunk):
            switch chunk.status {
            case .pendingUpload, .uploading, .uploadError:
                pendingChunkSizes[chunk.sequenceNumber] = chunk.data.count
            case .success:
                pendingChunkSizes[chunk.sequenceNumber] = nil
                uploadedChunksCount += 1
                uploadedBytesCount += chunk.data.count
            }
            pendingChunksCount = pendingChunkSizes.count
            pendingBytesCount = pendingChunkSizes.values.reduce(0, +)
        }
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
