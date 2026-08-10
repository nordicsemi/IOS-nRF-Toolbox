//
//  BloodPressureViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 2/6/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - BloodPressureViewModel

@Observable
final class BloodPressureViewModel: @MainActor SupportedServiceViewModel {
    
    // MARK: Properties
    
    private(set) var currentValue: BloodPressureMeasurement?
    private(set) var features = BitField<BloodPressureMeasurement.Feature>()
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    
    private var bpsMeasurement: CBCharacteristic!
    private var bpsFlags: CBCharacteristic!
    private var cancellables = Set<AnyCancellable>()
    
    private let log = NordicLog(category: "BloodPressureViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.characteristics = characteristics
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: description
    
    var description: String {
        "Blood Pressure"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return BloodPressureView()
            .environment(self)
    }
    
    // MARK: onConnect()
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Blood Pressure service has set up successfully.")
        } catch {
            log.error("Blood Pressure service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    @MainActor
    func initializeCharacteristics() async throws {
        let characteristics: [Characteristic] = [
            .bloodPressureMeasurement, .bloodPressureFeature
        ]
        let cbCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        bpsMeasurement = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.bloodPressureMeasurement.uuid)
        bpsFlags = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.bloodPressureFeature.uuid)
        
        guard let bpsMeasurement else {
            log.error("Blood Presssure Measurement characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        guard let bpsFlags else {
            log.error("Blood Presssure Feature characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        if let initialValue = bpsMeasurement.value {
            currentValue = try? BloodPressureMeasurement(data: initialValue)
            log.debug("Obtained initial Blood Pressure Measurement.")
        }
        
        listenTo(bpsMeasurement)
        let bpsEnable = try await peripheral.setNotifyValue(true, for: bpsMeasurement).firstValue
        guard bpsEnable else { throw ServiceError.notificationsNotEnabled }
        log.debug("BPS Measurement.setNotifyValue(true): \(bpsEnable)")
        
        log.debug("Found Blood Pressure Feature.")
        let featureData = try await peripheral.readValue(for: bpsFlags).firstValue
        if let featureData, featureData.canRead(UInt16.self, atOffset: 0) {
            let featureFlags = UInt(featureData.littleEndianBytes(atOffset: 0, as: UInt16.self))
            self.features = BitField<BloodPressureMeasurement.Feature>(featureFlags)
        }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        bpsMeasurement = nil
        cancellables.removeAll()
    }
}

extension BloodPressureViewModel {
    
    // MARK: listenTo(:)
    
    func listenTo(_ bpsCharacteristic: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        peripheral.listenValues(for: bpsCharacteristic)
            .compactMap { [log] data -> BloodPressureMeasurement? in
                log.debug("Received Data \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) (\(data.count) bytes)")
                do {
                    let result = try BloodPressureMeasurement(data: data)
                    log.info(result.newDataLog())
                    return result
                } catch {
                    log.error("Error parsing data: \(error.localizedDescription)")
                    return nil
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [log] _ in
                log.debug("Completion")
            }, receiveValue: { [weak self] newValue in
                self?.currentValue = newValue
            })
            .store(in: &cancellables)
    }
}
