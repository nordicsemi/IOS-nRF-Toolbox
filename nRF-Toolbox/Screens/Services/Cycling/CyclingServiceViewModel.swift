//
//  CyclingServiceViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 10/12/24.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

private extension CBUUID {
    static let cscMeasurement = CBUUID(characteristic: .cscMeasurement)
    static let cscFeature = CBUUID(characteristic: .cscFeature)
}

// MARK: - CyclingServiceViewModel

@Observable
final class CyclingServiceViewModel: SupportedServiceViewModel {
    
    // MARK: Properties
    
    private(set) var data: CyclingData = .zero
    private(set) var travelDistance = Measurement<UnitLength>(value: 0, unit: .kilometers)
    private(set) var totalTravelDistance = Measurement<UnitLength>(value: 0, unit: .kilometers)
    private(set) var speed = Measurement<UnitSpeed>(value: 0, unit: .kilometersPerHour)
    private(set) var gearRatio: Double = 1
    private(set) var cadence: Int = 0
    
    var wheelSizeInches: Double = 29.0
    private func wheelLength() -> Measurement<UnitLength> {
        let wheelSize = Measurement<UnitLength>(value: self.wheelSizeInches, unit: .inches)
        return Measurement<UnitLength>(value: wheelSize.converted(to: .meters).value * .pi,
                                unit: .meters)
    }
    
    private(set) var features: BitField<CyclingFlag>?
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var cscMeasurement: CBCharacteristic!
    private var cscFeature: CBCharacteristic!
    
    private var cancellables: Set<AnyCancellable>
    private let log = NordicLog(category: "CyclingServiceViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
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
    
    // MARK: initializeCharacteristics()
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let serviceCharacteristics: [Characteristic] = [.cscMeasurement, .cscFeature]
        let discoveredCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            serviceCharacteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        cscMeasurement = discoveredCharacteristics.first(where: \.uuid, isEqualsTo: .cscMeasurement)
        cscFeature = discoveredCharacteristics.first(where: \.uuid, isEqualsTo: .cscFeature)
        
        guard cscMeasurement != nil else {
            log.error("Cycling Measurement characteristic is missing.")
            throw ServiceError.serviceDiscoveryFailed
        }
        
        guard cscFeature != nil else {
            log.error("Cycling Feature characteristic is missing.")
            throw ServiceError.serviceDiscoveryFailed
        }
    }
    
    // MARK: readFeatures()
    
    @MainActor
    func readFeatures() async throws {
        log.debug("\(type(of: self)).\(#function)")
        features = try await peripheral.readValue(for: cscFeature).tryMap { data in
            guard let data, data.canRead(UInt8.self, atOffset: 0) else {
                throw ServiceError.noData
            }
            return BitField<CyclingFlag>(RegisterValue(data[0]))
        }
        .timeout(.seconds(5), scheduler: DispatchQueue.main, customError: {
            ServiceError.timeout
        })
        .firstValue
        
        guard let features else { return }
        log.debug("Detected \(ListFormatter().string(from: features.map(\.description)).nilDescription) features.")
    }
    
    // MARK: startListening()
    
    func startListening() async throws {
        peripheral.listenValues(for: cscMeasurement)
            .compactMap { [log] in
                log.debug("Received \($0.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) bytes.")
                
                let result = try? CyclingData($0)
                if let result {
                    self.log.info(result.newDataLog())
                }
                
                return result
            }
            .sink { [log] completion in
                switch completion {
                case .finished:
                    log.debug("Finished!")
                case .failure(let error):
                    log.error("Error: \(error.localizedDescription)")
                }
            } receiveValue: { update in
                Task { @MainActor [weak self] in
                    self?.update(from: update)
                }
            }
            .store(in: &cancellables)
        
        // Enable Notifications
        log.debug("Enabling Cycling Speed & Cadence Notifications...")
        let isNotifyEnabled = try await peripheral.setNotifyValue(true, for: cscMeasurement).firstValue
        log.debug("CSCS Measurement setNotifyValue(true): \(isNotifyEnabled)")
        guard isNotifyEnabled else { throw ServiceError.notificationsNotEnabled }
    }
    
    // MARK: update(from:)
    
    @MainActor
    private func update(from newData: CyclingData) {
        log.debug("Parsed valid update Data.")
        if let speedUpdate = newData.speed(data, wheelLength: wheelLength()) {
            self.speed = speedUpdate
        }
        if let travelUpdate = newData.distance(data, wheelLength: wheelLength()) {
            self.travelDistance = travelUpdate
        }
        if let totalDistanceUpdate = newData.travelDistance(with: wheelLength()) {
            self.totalTravelDistance = totalDistanceUpdate
        }
        if let cadenceUpdate = newData.cadence(data) {
            self.cadence = cadenceUpdate
        }
        if let ratioUpdate = newData.gearRatio(data) {
            self.gearRatio = ratioUpdate
        }
        
        let wheelData = newData.wheelData ?? data.wheelData
        let crankData = newData.crankData ?? data.crankData
        self.data = CyclingData(wheelData: wheelData ?? .zero, crankData: crankData ?? .zero)
        self.log.info("Updated cycling data:\n\n\(self.data.getLogString())")
    }
    
    // MARK: description
    
    var description: String {
        "Cycling"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return CyclingDataView()
            .environment(self)
    }
    
    // MARK: onConnect()
    @MainActor
    func onConnect() async throws {
        log.debug("\(type(of: self)).\(#function)")
        try await initializeCharacteristics()
        try await readFeatures()
        try await startListening()
        log.info("Cycling service has set up successfully.")
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cancellables.removeAll()
    }
}
