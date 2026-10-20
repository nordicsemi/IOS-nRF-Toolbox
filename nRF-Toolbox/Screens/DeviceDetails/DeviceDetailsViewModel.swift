//
//  DeviceDetailsViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 12/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Combine
import CoreBluetoothMock
import Foundation
import SwiftUI
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

private extension Array {
    func firstOfType<T>(type: T.Type) -> T? {
        first(where: { $0 is T }).flatMap({ $0 as? T })
    }
}

// MARK: - DeviceDetailsViewModel

@MainActor
@Observable
final class DeviceDetailsViewModel {
    
    // MARK: Private Properties
    
    private var discoveredServices: [CBService] = []
    private var connectionCancellables = Set<AnyCancellable>()
    private var serviceCancellables = Set<AnyCancellable>()
    
    let centralManager: CentralManager
    let peripheral: Peripheral
    
    var id: UUID { peripheral.peripheral.identifier }
    
    var errors: ErrorsHolder = ErrorsHolder()
    
    var device: Device

    enum ScreenState {
        case discovering
        case ready
        case discoveryFailed
        case disconnected
    }

    var screenState: ScreenState {
        switch device.status {
        case .error, .userInitiatedDisconnection:
            return .disconnected
        case .connected, .connecting:
            break
        }
        if (errors.error as? ServiceError) == .serviceDiscoveryFailed
            || (errors.error as? AlertError) == .servicesNotFound {
            return .discoveryFailed
        }
        if isManualReconnect && !isInitialized {
            return .disconnected
        }
        return supportedServiceViewModels.isEmpty ? .discovering : .ready
    }

    private static let disconnectionGracePeriod: Duration = .seconds(1)
    private static let connectionStabilityPeriod: Duration = .seconds(2)

    private(set) var supportedServiceViewModels: [any SupportedServiceViewModel] = []

    private let log = NordicLog(category: "DeviceDetails.VM", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: Properties
    
    var showDeviceSheet: Bool = false
    var attributeTable: AttributeTable?
    var deviceInfo: DeviceInformation?
    var signalViewModel: SignalChartViewModel?
    var isInitialized: Bool = false
    var isManualReconnect: Bool = false

    // MARK: init
    
    init(cbPeripheral: CBPeripheral, centralManager: CentralManager, device: Device, previousServiceViewModels: [any SupportedServiceViewModel]? = nil) {
        self.peripheral = Peripheral(peripheral: cbPeripheral, delegate: ReactivePeripheralDelegate())
        self.centralManager = centralManager
        self.device = device

        listenForConnectionStatus()
        if let previousServiceViewModels, !previousServiceViewModels.isEmpty {
            supportedServiceViewModels = previousServiceViewModels
        }
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
}

// MARK: disconnect

extension DeviceDetailsViewModel {

    func onDisconnect() async {
        log.debug("\(type(of: self)).\(#function)")
        signalViewModel?.stopTimer()
        supportedServiceViewModels.forEach {
            $0.onDisconnect()
        }
        peripheral.peripheral.delegate = nil
    }

    func prepareForManualReconnect() {
        log.debug("\(type(of: self)).\(#function)")
        isManualReconnect = true
        isInitialized = false
    }

    func tearDown() {
        log.debug("\(type(of: self)).\(#function)")
        connectionCancellables.removeAll()
        serviceCancellables.removeAll()
        signalViewModel?.stopTimer()
        signalViewModel = nil
        supportedServiceViewModels.removeAll()
        peripheral.peripheral.delegate = nil
    }
}

// MARK: - Service View Models

extension DeviceDetailsViewModel {
    
    // MARK: supportedServiceViews
    
    @ViewBuilder
    func supportedServiceViews() -> some View {
        let includedViews = supportedServiceViewModels
            .filter { !($0 is BatteryViewModel) }
            .map { viewModel in
                Section(viewModel.description) {
                    AnyView(viewModel.attachedView)
                }
            }

        ForEach(0..<includedViews.count, id: \.self) { index in
            includedViews[index]
        }
    }
    
    // MARK: batteryServiceViewModel
    
    var batteryServiceViewModel: BatteryViewModel? {
        supportedServiceViewModels.firstOfType(type: BatteryViewModel.self)
    }
    
    // MARK: discoverSupportedServices()
    
    func discoverSupportedServices() async -> [Service] {
        log.debug("\(type(of: self)).\(#function)")
        log.info("Discovering services...")

        var discoveredServiceBadges: [Service] = []
        do {
            var viewModels: [any SupportedServiceViewModel] = []
            serviceCancellables.removeAll()

            discoveredServices = try await peripheral.discoverServices(serviceUUIDs: nil).firstValue
            try Task.checkCancellation()
            discoveredServiceBadges = discoveredServices.compactMap { Service.extendedFind(by: $0.uuid.uuidString) }

            let ids = device.services.map { $0.uuid }.filter { $0.isSupported() }
            let discoveredIds = discoveredServices.map { $0.uuid }
            let missingIds = ids.filter { !discoveredIds.contains($0) }
            if !missingIds.isEmpty {
                missingIds.forEach { log.error("Missing required service: \($0.toServiceName())") }
                throw ServiceError.serviceDiscoveryFailed
            }

            var table = AttributeTable()
            for service in discoveredServices {
                try Task.checkCancellation()
                table.addService(service)

                let characteristics: [CBCharacteristic] = try await peripheral.discoverCharacteristics(nil, for: service).firstValue
                for characteristic in characteristics {
                    table.addCharacteristic(characteristic, to: service)

                    let descriptors = try await peripheral.discoverDescriptors(for: characteristic).firstValue
                    
                    for descriptor in descriptors {
                        table.addDescriptor(descriptor, to: characteristic, in: service)
                    }
                }
                
                log.info("\(service.uuid.toServiceName()) service discovered.")
                
                AnalyticsHelper.onServiceDiscovered(uuid: service.uuid)
                
                switch service.uuid {
                case .nordicBlinkyService:
                    viewModels.append(BlinkyViewModel(peripheral: peripheral, characteristics: characteristics))
                case .quickStart:
                    viewModels.append(QuickStartViewModel(peripheral: peripheral, characteristics: characteristics))
                case .memfaultDiagnostic:
                    viewModels.append(ObservabilityViewModel(peripheral: peripheral, characteristics: characteristics))
                case .runningSpeedCadence:
                    viewModels.append(RunningServiceViewModel(peripheral: peripheral, characteristics: characteristics))
                case .cyclingSpeedCadence:
                    viewModels.append(CyclingServiceViewModel(peripheral: peripheral, characteristics: characteristics))
                case .healthThermometer:
                    viewModels.append(HealthThermometerViewModel(peripheral: peripheral, characteristics: characteristics))
                case .heartRate:
                    viewModels.append(HeartRateViewModel(peripheral: peripheral, characteristics: characteristics))
                case .bloodPressure:
                    viewModels.append(BloodPressureViewModel(peripheral: peripheral, characteristics: characteristics))
                    let cuffCharacteristics: [CBCharacteristic] = characteristics.filter { cbChar in
                        cbChar.uuid == Characteristic.intermediateCuffPressure.uuid
                    }
                    if cuffCharacteristics.hasItems {
                        log.info("Cuff Pressure Characteristic discovered.")
                        viewModels.append(CuffPressureViewModel(peripheral: peripheral, characteristics: characteristics))
                    }
                case .battery:
                    viewModels.append(BatteryViewModel(peripheral: peripheral, characteristics: characteristics))
                case .throughputService:
                    viewModels.append(ThroughputViewModel(peripheral, characteristics: characteristics))
                case .glucoseService:
                    viewModels.append(GlucoseViewModel(peripheral: peripheral, characteristics: characteristics))
                case .continuousGlucoseMonitoringService:
                    viewModels.append(CGMSViewModel(peripheral: peripheral, characteristics: characteristics))
                case .nordicsemiUART:
                    viewModels.append(UARTViewModel(peripheral: peripheral, characteristics: characteristics))
                case .deviceInformation:
                    deviceInfo = try await DeviceInformation(characteristics, peripheral: peripheral)
                default:
                    break
                }
            }

            attributeTable = table

            signalViewModel = SignalChartViewModel(peripheral: peripheral)
            signalViewModel?.startTimer()
            log.info("Initialised RSSI probing.")
            
            for case let quickStartViewModel as QuickStartViewModel in viewModels {
                quickStartViewModel.hardwareRevision = deviceInfo?.hardwareRevision
            }

            for supportedServiceViewModel in viewModels {
                try Task.checkCancellation()
                do {
                    try await supportedServiceViewModel.onConnect()
                } catch {
                    log.error("\(supportedServiceViewModel.description) set up failed: \(error.localizedDescription)")
                    throw ServiceError.serviceDiscoveryFailed
                }
                
                supportedServiceViewModel.errors
                    .drop(while: { value in // Default values from other services may override an actual error.
                        !value.hasAnyError()
                    })
                    .sink { [weak self] error in
                        self?.errors = error
                    }.store(in: &serviceCancellables)
            }

            try? await Task.sleep(for: Self.connectionStabilityPeriod)
            try Task.checkCancellation()
            guard peripheral.peripheral.state == .connected else {
                throw ServiceError.serviceDiscoveryFailed
            }

            supportedServiceViewModels = viewModels
            isInitialized = true
            isManualReconnect = false
            log.info("Successfully initialized connection with the peripheral.")
            
            return discoveredServiceBadges
        } catch {
            guard !Task.isCancelled else { return discoveredServiceBadges }
            if peripheral.peripheral.state == .connected {
                try? await Task.sleep(for: Self.disconnectionGracePeriod)
                guard !Task.isCancelled else { return discoveredServiceBadges }
            }
            supportedServiceViewModels.removeAll()
            guard peripheral.peripheral.state == .connected else {
                log.info("\(#function) interrupted by disconnection: \(error.localizedDescription)")
                return discoveredServiceBadges
            }
            if case let serviceError as ServiceError = error {
                errors.error = serviceError
            } else {
                errors.error = AlertError.servicesNotFound
            }
            log.error("\(#function) Error: \(error.localizedDescription)")
            return discoveredServiceBadges
        }
    }
    
    // MARK: listenForConnectionStatus()

    private func listenForConnectionStatus() {
        connectionCancellables.removeAll()

        centralManager.disconnectedPeripheralsChannel
            .filter { [weak self] in $0.0.identifier == self?.id }
            .compactMap { $0.1 }
            .sink { [weak self] error in
                guard let self else { return }
                log.info("Connection lost: \(error.localizedDescription). Waiting for reconnection.")
                supportedServiceViewModels.forEach {
                    $0.onDisconnect()
                }
                signalViewModel?.stopTimer()
            }
            .store(in: &connectionCancellables)
    }
}

extension DeviceDetailsViewModel {

    // MARK: AlertError
    
    enum AlertError: LocalizedError {
        case servicesNotFound

        var description: String? {
            switch self {
            case .servicesNotFound:
                return "Services not found"
            }
        }

        var errorDescription: String? {
            switch self {
            case .servicesNotFound:
                return "Error occured while discovering services."
            }
        }
    }
}

extension CBUUID {
    
    func toServiceName() -> String {
        return switch self {
        case .nordicBlinkyService:
            "Blinky"
        case .quickStart:
            "Quick Start"
        case .memfaultDiagnostic:
            "Observability"
        case .runningSpeedCadence:
            "Running Speed and Cadence"
        case .cyclingSpeedCadence:
            "Cycling Speed and Cadence"
        case .healthThermometer:
            "Health Thermometer"
        case .heartRate:
            "Heart Rate"
        case .bloodPressure:
            "Blood Pressure"
        case .battery:
            "Battery"
        case .throughputService:
            "Throughput"
        case .glucoseService:
            "Glucose"
        case .continuousGlucoseMonitoringService:
            "Continous Glucose"
        case .nordicsemiUART:
            "UART"
        case .deviceInformation:
            "Device Information"
        default:
            "Unknown"
        }
    }
    
    func isSupported() -> Bool {
        return switch self {
        case .nordicBlinkyService,
                .quickStart,
                .memfaultDiagnostic,
                .runningSpeedCadence,
                .cyclingSpeedCadence,
                .healthThermometer,
                .heartRate,
                .bloodPressure,
                .battery,
                .throughputService,
                .glucoseService,
                .continuousGlucoseMonitoringService,
                .nordicsemiUART,
                .deviceInformation:
            true
        default:
            false
        }
    }
}
