//
//  ConnectedDevicesViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 11/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import iOS_BLE_Library_Mock
import Combine
import iOS_Bluetooth_Numbers_Database

// MARK: - ConnectedDevicesViewModel

@MainActor
@Observable
final class ConnectedDevicesViewModel {
    
    // MARK: ScannerState
    
    enum ScannerState {
        case scanning, unsupported, disabled, unauthorized
    }
    
    // MARK: Properties
    
    fileprivate(set) var devices: [ConnectedDevicesViewModel.ScanResult]
    var connectingDevice: ConnectedDevicesViewModel.ScanResult?
    fileprivate(set) var scannerState: ScannerState
    
    fileprivate(set) var connectedDevices: [Device]
    var selectedDevice: Device? {
        didSet {
            if let d = connectedDevices.first(where: { $0 == selectedDevice }) {
                print(d.name ?? "")
            } else {
                print("no selection")
            }
        }
    }
    
    var showUnexpectedDisconnectionAlert: Bool = false
    fileprivate(set) var unexpectedDisconnectionMessage: String = ""
    
    // MARK: Private Properties
    
    private let centralManager: CentralManager
    private var deviceViewModels: [UUID: DeviceDetailsViewModel] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var scannerCancellables = Set<AnyCancellable>()
    
    private let log = NordicLog(category: "ConnectedDevicesViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    // MARK: init
    
    init(centralManager: CentralManager) {
        self.centralManager = centralManager
        self.connectedDevices = []
        self.selectedDevice = nil
        self.devices = []
        self.connectingDevice = nil
        self.scannerState = .disabled
        observeStateChange()
        observeConnections()
        observeDisconnections()
        log.debug("\(type(of: self)).\(#function)")
    }
}

extension ConnectedDevicesViewModel {
    
    // MARK: deviceViewModel(for:)
    
    func deviceViewModel(for deviceID: Device.ID) -> DeviceDetailsViewModel? {
        guard let deviceViewModel = deviceViewModels[deviceID] else {
            // Can return 'nil' after disconnect
            return nil
        }
        return deviceViewModel
    }
    
    // MARK: disconnectAndRemoveViewModel()
    
    func disconnectAndRemoveViewModel(_ device: Device) async throws {
        log.debug("\(type(of: self)).\(#function)")
        let deviceID = device.id
        log.info("Disconnecting from the device: \(device.logName)")
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [deviceID]).first else { return }
        guard let deviceViewModel = deviceViewModels[deviceID] else { return }
        
        await deviceViewModel.onDisconnect()
        if let i = connectedDevices.firstIndex(where: \.id, equals: deviceID) {
            let device = connectedDevices[i]
            connectedDevices[i].status = .userInitiatedDisconnection
            deviceViewModels[device.id]?.device = connectedDevices[i]
        }
        
        defer {
            clearViewModel(device)
        }
        
        do {
            _ = try await centralManager.cancelPeripheralConnection(peripheral).firstValue
        } catch {
            log.error(error.localizedDescription)
        }
    }
    
    // MARK: clearViewModel(:)

    func clearViewModel(_ device: Device) {
        log.debug("\(type(of: self)).\(#function)")
        connectedDevices.removeAll(where: { $0.id == device.id })
        deviceViewModels.removeValue(forKey: device.id)
        log.info("Device successfully removed: \(device.logName)")
    }

    // MARK: reconnect(:)

    func reconnect(_ device: Device) async {
        log.debug("\(type(of: self)).\(#function)")
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [device.id]).first else { return }
        log.info("Reconnecting to the device: \(device.logName)")

        if let i = connectedDevices.firstIndex(where: \.id, equals: device.id) {
            connectedDevices[i].status = .connecting
            deviceViewModels[device.id]?.device = connectedDevices[i]
            deviceViewModels[device.id]?.errors = ErrorsHolder()
        }

        do {
            _ = try await centralManager.connect(peripheral)
                .timeout(.seconds(5), scheduler: DispatchQueue.main, customError: {
                    ConnectionError.connectionTimeout
                })
                .first()
                .firstValue
            // On success, `observeConnections()` picks up the new connection and
            // rebuilds the device's status/view model through the normal connect flow.
        } catch {
            log.error("\(#function) Error: \(error.localizedDescription)")
            if let i = connectedDevices.firstIndex(where: \.id, equals: device.id) {
                connectedDevices[i].status = .error(error)
                deviceViewModels[device.id]?.device = connectedDevices[i]
            }
        }
    }
}

extension ConnectedDevicesViewModel {
    
    // MARK: observeStateChange()
    
    private func observeStateChange() {
        log.debug("\(type(of: self)).\(#function)")
        centralManager.stateChannel
            .sink { [log, weak self] state in
                log.debug("BLE State changed to \(state).")
                switch state {
                case .poweredOff, .unauthorized, .unsupported:
                    log.error("Bluetooth is off.")
                    guard let self else { return }
                    for i in connectedDevices.indices {
                        let device = connectedDevices[i]
                        connectedDevices[i].status = .error(ConnectionError.bluetoothUnavailable)
                        deviceViewModels[device.id]?.device = connectedDevices[i]
                    }
                case .poweredOn:
                    log.info("Bluetooth is on.")
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: observeConnections()
    
    private func observeConnections() {
        log.debug("\(type(of: self)).\(#function)")
        centralManager.connectedPeripheralChannel
            .map { $0 } // Remove <Never> as $1
            .filter { $0.1 == nil } // No connection error
            .receive(on: RunLoop.main)
            .map { [weak self] (peripheral: CBPeripheral, error: Error?) -> Device in
                let device = self?.devices.first(where: \.id, isEqualsTo: peripheral.identifier)
                let advertisedServices = device?.services ?? Set<Service>()
                let name = device?.name ?? peripheral.name
                
                return Device(
                    name: name,
                    id: peripheral.identifier,
                    services: advertisedServices,
                    status: .connected
                )
            }
            .sink { [unowned self] device in
                handleConnection(device: device)
            }
            .store(in: &cancellables)
    }
    
    private func handleConnection(device: Device) {
        log.info("Connecting to the device: \(device.logName)")
        if let i = connectedDevices.firstIndex(where: \.id, equals: device.id) {
            connectedDevices[i] = device
        } else {
            connectedDevices.append(device)
        }

        if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [device.id]).first {
            let viewModel = DeviceDetailsViewModel(cbPeripheral: peripheral, centralManager: centralManager, device: device)
            deviceViewModels[device.id] = viewModel
            Task {
                let services = await viewModel.discoverSupportedServices()
                if let i = connectedDevices.firstIndex(where: \.id, equals: device.id) {
                    var connectedDevice = connectedDevices[i]
                    connectedDevice.services.formUnion(Set(services))
                    connectedDevices[i] = connectedDevice
                    deviceViewModels[device.id]?.device = connectedDevices[i]
                }
            }
        }
    }
    
    // MARK: observeDisconnections()
    
    private func observeDisconnections() {
        log.debug("\(type(of: self)).\(#function)")
        centralManager.disconnectedPeripheralsChannel
            .sink { [unowned self] (peripheral, error) in
                guard let i = self.connectedDevices.firstIndex(where: \.id, equals: peripheral.identifier) else {
                    return
                }
                
                let disconnectedDevice = self.connectedDevices[i]
                self.log.debug("Disconnected Device Status: \(disconnectedDevice.status)")
                if let error {
                    let device = connectedDevices[i]
                    self.connectedDevices[i].status = .error(error)
                    deviceViewModels[device.id]?.device = connectedDevices[i]
                } else {
                    self.connectedDevices.remove(at: i)
                }
                
                if disconnectedDevice.status.hashValue != Device.Status.userInitiatedDisconnection.hashValue {
                    self.showUnexpectedDisconnectionAlert = true
                    self.unexpectedDisconnectionMessage = "\(disconnectedDevice.name ?? "Unnamed Device") disconnected unexpectedly."
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - ConnectionError

extension ConnectedDevicesViewModel {
    
    enum ConnectionError: LocalizedError {
        case bluetoothUnavailable
        case connectionTimeout
        case ongoingConnection
        
        var errorDescription: String? {
            switch self {
            case .bluetoothUnavailable:
                return "The connection was lost because Bluetooth was disabled."
            case .connectionTimeout:
                return "Timeout when attempting to connect."
            case .ongoingConnection:
                return "Another connection is in progress."
            }
        }
    }
}

// MARK: - Scanner

extension ConnectedDevicesViewModel {
    
    // MARK: connect(to:)
    
    @MainActor
    func connect(to device: ConnectedDevicesViewModel.ScanResult) async -> Result<Void, Error> {
        log.debug("\(type(of: self)).\(#function)")
        if connectingDevice != nil {
            return Result.failure(ConnectionError.ongoingConnection)
        }
        
        connectingDevice = device
        
        // Get CBPeripheral's instance
        let peripheral = centralManager.retrievePeripherals(withIdentifiers: [device.id]).first!
        do {
            // `connect` method returns Publisher that sends connected CBPeripheral
            let connectedDevice = try await centralManager.connect(peripheral)
                .timeout(.seconds(2), scheduler: DispatchQueue.main, customError: {
                    return ConnectionError.connectionTimeout
                })
                .first()
                .firstValue
            log.debug("Connected to \(connectedDevice)")
        } catch let error {
            return Result.failure(error)
        }
        return Result.success(Void())
    }
    
    @MainActor
    func handleError(result: Result<Void, Error>) {
        if case .failure(let error) = result {
            log.error("Error: \(error.localizedDescription)")
            self.unexpectedDisconnectionMessage = error.localizedDescription
            self.showUnexpectedDisconnectionAlert = true
        }
    }
    
    // MARK: setupManager()
    
    func setupManager() {
        log.debug("\(type(of: self)).\(#function)")
        guard scannerCancellables.isEmpty else { return }
        // Track state CBCentralManager's state changes
        centralManager.stateChannel
            .map { state -> ScannerState in
                switch state {
                case .poweredOff:
                    return .disabled
                case .unauthorized:
                    return .unauthorized
                case .unsupported:
                    return .unsupported
                default:
                    return .scanning
                }
            }
            .sink(receiveValue: { value in
                self.scannerState = value
            })
            .store(in: &cancellables)
        
        guard centralManager.centralManager.state == .poweredOn else { return }
    }
    
    // MARK: startScanning()
    
    func startScanning() {
        log.debug("\(type(of: self)).\(#function)")
        Task {
            guard (try? await centralManager.isPoweredOn()) != nil else { return }

            centralManager.scanForPeripherals(withServices: nil)
                .filter {
                    // Filter unconnectable devices
                    return $0.advertisementData.isConnectable == true
                }
                .map { result -> ConnectedDevicesViewModel.ScanResult in
                    ConnectedDevicesViewModel.ScanResult(
                        name: result.advertisementData.localName ?? result.name,
                        rssi: result.rssi.value,
                        id: result.peripheral.identifier,
                        services: result.advertisementData.serviceUUIDs?.compactMap { $0.uuidString } ?? []
                    )
                }
                .sink { completion in
                    if case .failure(let error) = completion {
                        self.unexpectedDisconnectionMessage = error.localizedDescription
                    }
                } receiveValue: { result in
                    if let i = self.devices.firstIndex(where: \.id, equals: result.id) {
                        let existingDevice = self.devices[i]
                        self.devices[i] = existingDevice.extend(using: result)
                    } else {
                        self.devices.append(result)
                    }
                }
                .store(in: &scannerCancellables)
        }
    }
    
    // MARK: stopScanning()
    
    func stopScanning() {
        log.debug("\(type(of: self)).\(#function)")
        centralManager.stopScan()
        scannerCancellables.removeAll()
    }
    
    // MARK: refresh()
    
    func refresh() {
        stopScanning()
        devices.removeAll()
        setupManager()
        startScanning()
    }
}
