//
//  RunningServiceViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 16/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries
import Combine

// MARK: - RunningServiceViewModel

final class RunningServiceViewModel: @MainActor SupportedServiceViewModel {
    
    let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    
    lazy private(set) var environment = Environment()
    
    // MARK: Mandatory Characteristics
    var rscMeasurement: CBCharacteristic!
    var rscFeature: CBCharacteristic!
    var scControlPoint: CBCharacteristic?
    
    private var cancelable = Set<AnyCancellable>()
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    private let log = NordicLog(category: "RunningService.ViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.characteristics = characteristics
        log.debug("\(type(of: self)).\(#function)")
    }
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: description
    
    var description: String {
        "Running"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return RunningServiceView()
            .environment(self.environment)
    }
    
    // MARK: onConnect()
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Running service has set up successfully.")
        } catch {
            log.error("Running service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cancelable.removeAll()
    }
}

extension RunningServiceViewModel {
    
    // MARK: initializeCharacteristics()
    @MainActor
    public func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        try await setUpGlobalVariables()
        try await readFeature()
        
        try await enableMeasurementNotifications()
    }
}

private extension RunningServiceViewModel {
    
    // MARK: setUpGlobalVariables()
    @MainActor
    func setUpGlobalVariables() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let characteristics: [Characteristic] = [.rscMeasurement, .rscFeature, .scControlPoint]
        let discoveredCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        rscMeasurement = discoveredCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.rscMeasurement.uuid)
        rscFeature = discoveredCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.rscFeature.uuid)
        scControlPoint = discoveredCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.scControlPoint.uuid)
        
        self.environment.isSensorCalibrationAvailable = scControlPoint != nil
        
        guard rscMeasurement != nil else {
            log.error("Running Measurement characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        guard rscFeature != nil else {
            log.error("Running Feature characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
    }
    
    // MARK: readFeature()
    @MainActor
    func readFeature() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let features = try await peripheral.readValue(for: rscFeature)
            .tryMap { data in
                guard let data else { throw ServiceError.noData }
                return BitField<RSCSFeature>(RegisterValue(data[0]))
            }
            .timeout(.seconds(1), scheduler: DispatchQueue.main, customError: { ServiceError.timeout })
            .firstValue
        
        let calibrationViewModel = SensorCalibrationViewModel(peripheral: peripheral, characteristics: characteristics, features: features)
        environment.sensorCalibrationViewModel = calibrationViewModel
        await calibrationViewModel.initializeCharacteristic()
        await calibrationViewModel.readLocations()
        environment.features = features
    }
    
    // MARK: enableMeasurementNotifications()
    
    func enableMeasurementNotifications() async throws {
        peripheral.listenValues(for: rscMeasurement)                    // Listen for values
            .compactMap { data in
                self.log.debug("Received \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) bytes.")
                
                let result = try? RSCSMeasurement(from: data)
                if let result {
                    self.log.info(result.newDataLog())
                }
                
                return result
            }
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] completion in
                switch completion {
                case .finished:
                    self.log.debug("Finished!")
                case .failure(let error):
                    self.log.error("error: \(error.localizedDescription)")
                }
                
            } receiveValue: { [unowned self] measurement in
                self.environment.instantaneousSpeed = measurement.instantaneousSpeed
                self.environment.instantaneousCadence = Int(measurement.instantaneousCadence)
                
                if measurement.flags.contains(.instantaneousStrideLengthMeasurement) {
                    self.environment.instantaneousStrideLength = measurement.instantaneousStrideLength
                }
                
                if measurement.flags.contains(.totalDistanceMeasurement) {
                    self.environment.totalDistance = measurement.totalDistance
                }
                
                self.environment.isRunning = measurement.flags.contains(.walkingOrRunningStatus)
            }
            .store(in: &cancelable)
        
        let isNotifyEnabled = try await peripheral.setNotifyValue(true, for: rscMeasurement).firstValue
        log.debug("RSCS Measurement setNotifyValue(true): \(isNotifyEnabled)")
        guard isNotifyEnabled else { throw ServiceError.notificationsNotEnabled }
    }
}

// MARK: - Environment

extension RunningServiceViewModel {
    
    @Observable
    class Environment {
        fileprivate(set) var criticalError: CriticalError?
        fileprivate(set) var alertError: AlertError?
        
        fileprivate(set) var features = BitField<RSCSFeature>()
        
        var instantaneousSpeed: Measurement<UnitSpeed>?
        var instantaneousCadence: Int?
        var instantaneousStrideLength: Measurement<UnitLength>?
        var totalDistance: Measurement<UnitLength>?
        var isRunning: Bool?
        var isSensorCalibrationAvailable: Bool?
        
        var sensorCalibrationViewModel: SensorCalibrationViewModel?
        
        private let log = NordicLog(category: "RunningService.ViewModel.Environment")
        
        init(criticalError: CriticalError? = nil, alertError: AlertError? = nil,
             features: BitField<RSCSFeature> = [],
             instantaneousSpeed: Measurement<UnitSpeed>? = nil,
             instantaneousCadence: Int? = nil,
             instantaneousStrideLength: Measurement<UnitLength>? = nil,
             totalDistance: Measurement<UnitLength>? = nil,
             isRunning: Bool? = nil) {
            self.criticalError = criticalError
            self.alertError = alertError
            self.features = features
            self.instantaneousSpeed = instantaneousSpeed
            self.instantaneousCadence = instantaneousCadence
            self.instantaneousStrideLength = instantaneousStrideLength
            self.totalDistance = totalDistance
            self.isRunning = isRunning
            
            log.debug("\(type(of: self)).\(#function)")
        }
        
        deinit {
            log.debug("\(type(of: self)).\(#function)")
        }
    }
}

// MARK: - Error

extension RunningServiceViewModel.Environment {
    
    enum CriticalError: Error {
        case noMandatoryCharacteristics
        case noData
        case unknown
    }
    
    enum AlertError: Error { }
}

// MARK: - CriticalError

extension RunningServiceViewModel.Environment.CriticalError {
    
    var readableError: ReadableError {
        switch self {
        case .noMandatoryCharacteristics:
            ReadableError(title: "Error", message: "Can't discover mandatory characteristics")
        case .noData:
            ReadableError(title: "Error", message: "Can't read required data")
        case .unknown:
            ReadableError(title: "Error", message: "An unknown error has occurred")
        }
    }
}
