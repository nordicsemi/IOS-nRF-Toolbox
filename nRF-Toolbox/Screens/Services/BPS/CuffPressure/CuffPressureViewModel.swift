//
//  CuffPressureViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 2/7/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - CuffPressureViewModel

@Observable
final class CuffPressureViewModel: @MainActor SupportedServiceViewModel {
    
    // MARK: Properties
    
    private(set) var currentValue: CuffPressureMeasurement?
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    
    private var cuffMeasurement: CBCharacteristic!
    private var cancellables = Set<AnyCancellable>()
    
    private let log = NordicLog(category: "CuffPressureViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

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
        "Cuff Pressure"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return CuffPressureView()
            .environment(self)
    }
    
    // MARK: onConnect()
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
        } catch {
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let characteristics: [Characteristic] = [
            .intermediateCuffPressure
        ]
        let cbCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        cuffMeasurement = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.intermediateCuffPressure.uuid)
        
        if let cuffMeasurement {
            log.debug("Found Intermediate Cuff Pressure Measurement \(cuffMeasurement.uuid)")
            let cuffData = try? await peripheral.readValue(for: cuffMeasurement).firstValue
            if let cuffData {
                currentValue = try? CuffPressureMeasurement(data: cuffData)
                log.debug("Obtained initial Intermediate Cuff Pressure Measurement.")
            }
            
            listenTo(cuffMeasurement)
            let cuffEnable = try await peripheral.setNotifyValue(true, for: cuffMeasurement).firstValue
            guard cuffEnable else { throw ServiceError.notificationsNotEnabled }
            log.debug("Cuff Measurement.setNotifyValue(true): \(cuffEnable)")
        }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cuffMeasurement = nil
        cancellables.removeAll()
    }
}

extension CuffPressureViewModel {
    
    // MARK: listenTo(:)
    
    func listenTo(_ cuffCharacteristic: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        peripheral.listenValues(for: cuffCharacteristic)
            .compactMap { [log] data -> CuffPressureMeasurement? in
                log.debug("Received Cuff Data \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) (\(data.count) bytes)")
                do {
                    return try CuffPressureMeasurement(data: data)
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
