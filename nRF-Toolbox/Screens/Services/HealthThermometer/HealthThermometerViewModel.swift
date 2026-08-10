//
//  HealthThermometerViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 12/12/24.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - HealthThermometerViewModel

@Observable
final class HealthThermometerViewModel: SupportedServiceViewModel {
    
    // MARK: Properties
    
    private(set) var measurement: TemperatureMeasurement?
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var cancellables: Set<AnyCancellable>
    private let log = NordicLog(category: "TemperatureViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.characteristics = characteristics
        self.cancellables = Set<AnyCancellable>()
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
  
    // MARK: description
    
    var description: String {
        "Health Thermometer"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return HealthThermometerView()
            .environment(self)
    }
    
    // MARK: onConnect()
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Health Thermometer service has set up successfully.")
        } catch {
            log.error("Health Thermometer service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        
        let characteristics: [Characteristic] = [.temperatureMeasurement]
        
        let measurementCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        guard let temperatureMeasurement = measurementCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.temperatureMeasurement.uuid) else {
            log.error("Health Thermometer Measurement characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        listenTo(temperatureMeasurement)
        let isNotifyEnabled = try await peripheral.setNotifyValue(true, for: temperatureMeasurement).firstValue
        log.debug("HTS Measurement setNotifyValue(true): \(isNotifyEnabled)")
        guard isNotifyEnabled else { throw ServiceError.notificationsNotEnabled }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cancellables.removeAll()
    }
    
    func listenTo(_ characteristic: CBCharacteristic) {
        peripheral.listenValues(for: characteristic)
            .map { data in
                self.log.debug("Received measurement data: \(data.hexEncodedString(options: [.upperCase, .twoByteSpacing]))")
                
                let result = try? TemperatureMeasurement(data)
                if let result {
                    self.log.info(result.newDataLog())
                }
                
                return result
            }
            .receive(on: DispatchQueue.main)
            .sink(to: \.measurement, in: self, assigningInCaseOfError: nil)
            .store(in: &cancellables)
    }
}
