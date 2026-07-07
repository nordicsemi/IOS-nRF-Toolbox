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
    private var cancellable = Set<AnyCancellable>()
    
    let centralManager: CentralManager
    let peripheral: Peripheral
    
    var id: UUID { peripheral.peripheral.identifier }
    
    var errors: ErrorsHolder = ErrorsHolder()
    
    var device: ConnectedDevicesViewModel.Device
    
    private(set) var supportedServiceViewModels: [any SupportedServiceViewModel] = []
    
    private let log = NordicLog(category: "DeviceDetails.VM", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: Properties
    
    var showDeviceSheet: Bool = false
    var attributeTable: AttributeTable?
    var deviceInfo: DeviceInformation?
    var signalViewModel: SignalChartViewModel?
    var isInitialized: Bool = false
    
    // MARK: init
    
    init(cbPeripheral: CBPeripheral, centralManager: CentralManager, device: ConnectedDevicesViewModel.Device) {
        self.peripheral = Peripheral(peripheral: cbPeripheral, delegate: ReactivePeripheralDelegate())
        self.centralManager = centralManager
        self.device = device
        
        listenForDisconnection()
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
}

// MARK: disconnect / reconnect

extension DeviceDetailsViewModel {
    private struct TimeoutError: Error { }
    
    func reconnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            _ = try await centralManager.connect(peripheral.peripheral)
                // Set timeout for 5 seconds
                .timeout(5, scheduler: DispatchQueue.main, customError: {
                    TimeoutError()
                })
                .firstValue
        } catch {
            log.error("\(#function) Error: \(error.localizedDescription)")
            await onDisconnect()
        }
    }
    
    func onDisconnect() async {
        log.debug("\(type(of: self)).\(#function)")
        signalViewModel?.stopTimer()
        supportedServiceViewModels.forEach {
            $0.onDisconnect()
        }
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
    
    func discoverSupportedServices() async {
        log.debug("\(type(of: self)).\(#function)")
        log.info("Discovering services...")
        do {
            if supportedServiceViewModels.hasItems {
                await onDisconnect()
                supportedServiceViewModels.removeAll()
            }

            discoveredServices = try await peripheral.discoverServices(serviceUUIDs: nil).firstValue
            
            let ids = device.services.map { $0.uuid }.filter { $0.isSupported() }
            let discoveredIds = discoveredServices.map { $0.uuid }
            let missingIds = ids.filter { !discoveredIds.contains($0) }
            if !missingIds.isEmpty {
                missingIds.forEach { log.error("Missing required service: \($0.toServiceName())") }
                throw ServiceError.noMandatoryCharacteristic
            }
            
            var table = AttributeTable()
            for service in discoveredServices {
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
                
                switch service.uuid {
                case .nordicBlinkyService:
                    supportedServiceViewModels.append(BlinkyViewModel(peripheral: peripheral, characteristics: characteristics))
                case .quickStartService:
                    supportedServiceViewModels.append(QuickStartViewModel(peripheral: peripheral, characteristics: characteristics))
                case .memfaultDiagnosticService:
                    supportedServiceViewModels.append(ObservabilityViewModel(peripheral: peripheral, characteristics: characteristics))
                case .runningSpeedCadence:
                    supportedServiceViewModels.append(RunningServiceViewModel(peripheral: peripheral, characteristics: characteristics))
                case .cyclingSpeedCadence:
                    supportedServiceViewModels.append(CyclingServiceViewModel(peripheral: peripheral, characteristics: characteristics))
                case .healthThermometer:
                    supportedServiceViewModels.append(HealthThermometerViewModel(peripheral: peripheral, characteristics: characteristics))
                case .heartRate:
                    supportedServiceViewModels.append(HeartRateViewModel(peripheral: peripheral, characteristics: characteristics))
                case .bloodPressure:
                    supportedServiceViewModels.append(BloodPressureViewModel(peripheral: peripheral, characteristics: characteristics))
                    let cuffCharacteristics: [CBCharacteristic] = characteristics.filter { cbChar in
                        cbChar.uuid == Characteristic.intermediateCuffPressure.uuid
                    }
                    if cuffCharacteristics.hasItems {
                        log.info("Cuff Pressure Characteristic discovered.")
                        supportedServiceViewModels.append(CuffPressureViewModel(peripheral: peripheral, characteristics: characteristics))
                    }
                case .battery:
                    supportedServiceViewModels.append(BatteryViewModel(peripheral: peripheral, characteristics: characteristics))
                case .throughputService:
                    supportedServiceViewModels.append(ThroughputViewModel(peripheral, characteristics: characteristics))
                case .glucoseService:
                    supportedServiceViewModels.append(GlucoseViewModel(peripheral: peripheral, characteristics: characteristics))
                case .continuousGlucoseMonitoringService:
                    supportedServiceViewModels.append(CGMSViewModel(peripheral: peripheral, characteristics: characteristics))
                case .nordicsemiUART:
                    supportedServiceViewModels.append(UARTViewModel(peripheral: peripheral, characteristics: characteristics))
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
            
            for supportedServiceViewModel in self.supportedServiceViewModels {
                await supportedServiceViewModel.onConnect()
                
                supportedServiceViewModel.errors
                    .drop(while: { value in // Default values from other services may override an actual error.
                        !value.hasAnyError()
                    })
                    .sink { [weak self] error in
                        self?.errors = error
                    }.store(in: &cancellable)
            }
            
            isInitialized = true
            log.info("Successfully initialized connection with the peripheral.")
        } catch {
            if case let serviceError as ServiceError = error {
                errors.error = serviceError
            } else {
                errors.error = AlertError.servicesNotFound
            }
            log.error("\(#function) Error: \(error.localizedDescription)")
        }
    }
    
    private func listenForDisconnection() {
        centralManager.disconnectedPeripheralsChannel
            .filter { [unowned self] in $0.0.identifier == self.id }    // Filter other peripherals
            .compactMap { $0.1 }                                        // Handle only disconnections with error
            .sink { [unowned self] err in
                supportedServiceViewModels.forEach {
                    $0.onDisconnect()
                }
                signalViewModel?.stopTimer()
            }
            .store(in: &cancellable)
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
        case .quickStartService:
            "Quick Start"
        case .memfaultDiagnosticService:
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
