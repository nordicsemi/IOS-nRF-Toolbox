//
//  GlucoseViewModel.swift
//  nRF Toolbox
//
//  Created by Dinesh Harjani on 6/6/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - GlucoseViewModel

@Observable
final class GlucoseViewModel: @MainActor SupportedServiceViewModel {
    
    // MARK: Published
    
    var scrollPosition = -1
    private(set) var allRecords = [GlucoseMeasurement]()
    private(set) var firstRecord: GlucoseMeasurement?
    private(set) var lastRecord: GlucoseMeasurement?
    private(set) var inFlightRequest: RecordOperator?
    private(set) var minY = 0.6
    private(set) var maxY = 0.0
    private(set) var maxX = 20.0
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var cbGlucoseMeasurement: CBCharacteristic!
    private var cbRACP: CBCharacteristic!
    private var glucoseNotifyEnabled: Bool = false
    
    private var cancellables: Set<AnyCancellable>
    private let log = NordicLog(category: "GlucoseViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
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
        "Glucose Service"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return GlucoseView()
            .environment(self)
    }
    
    // MARK: onConnect()
    
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Glucose service has set up successfully.")
        } catch {
            log.error("Glucose service set up failed.")
            log.error("Error \(error.localizedDescription)")
            inFlightRequest = nil
            handleError(error)
        }
    }
    
    @MainActor
    private func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let characteristics: [Characteristic] = [
            .glucoseMeasurement, .glucoseFeature,
            .recordAccessControlPoint
        ]
        let cbCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        cbGlucoseMeasurement = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.glucoseMeasurement.uuid)
        cbRACP = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.recordAccessControlPoint.uuid)
        guard cbGlucoseMeasurement != nil else {
            log.error("Glucose measurement characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        requestRecords(.allRecords)
    }
    
    fileprivate func enableNotificationsIfNeeded() async throws {
        if glucoseNotifyEnabled { return }
        
        listenToMeasurements(cbGlucoseMeasurement)
        glucoseNotifyEnabled = try await peripheral.setNotifyValue(true, for: cbGlucoseMeasurement)
            .receive(on: DispatchQueue.main)
            .firstValue
        log.debug("GlucoseMeasurement.setNotifyValue(true): \(glucoseNotifyEnabled)")
        
        guard glucoseNotifyEnabled else { throw ServiceError.notificationsNotEnabled }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cbGlucoseMeasurement = nil
        cbRACP = nil
        cancellables.removeAll()
    }
}

// MARK: API

extension GlucoseViewModel {
    
    // MARK: requestRecords()
    
    nonisolated
    func requestRecords(_ op: RecordOperator) {
        Task { @MainActor in
            guard let cbRACP else { return }
            
            log.debug("\(type(of: self)).\(#function)")
            do {
                inFlightRequest = op
                defer {
                    inFlightRequest = nil
                }

                try await enableNotificationsIfNeeded()
                guard glucoseNotifyEnabled else { return }
                
                log.info(requestRecordsInfo(op))
                
                if op == .allRecords {
                    allRecords.removeAll()
                }
                
                // If we don't listen to RACP and GLS Measurements, our firmware
                // will restart, fail, crash, or complain. Don't ask.
                let turnOnIndications = try await peripheral.setNotifyValue(true, for: cbRACP).firstValue
                log.debug("peripheral.setIndicate(true): \(turnOnIndications)")
                
                log.debug("peripheral.listenToRACPRequest()")
                async let racpResult = try peripheral.listenValues(for: cbRACP).firstValue
                
                let writeData = Data([RecordOpcode.reportStoredRecords.rawValue, op.rawValue])
                log.debug("peripheral.writeValueWithResponse(\(writeData.hexEncodedString(options: [.prepend0x, .upperCase])))")
                try await peripheral.writeValueWithResponse(writeData, for: cbRACP).firstValue
                
                let resultData = try await racpResult
                guard resultData.canRead(UInt8.self, atOffset: 0) else {
                    throw CriticalError.cannotFindGlucoseMeasurementCCD
                }
                log.debug("RACP Request Result: \(resultData)")
                try processRACPResponse(resultData)
                
                // Keep our nose clean by turning notifications back off.
                let turnOffIndications = try await peripheral.setNotifyValue(false, for: cbRACP).firstValue
                log.debug("peripheral.setIndicate(false): \(turnOffIndications)")
            } catch {
                log.error("\(#function) Error: \(error.localizedDescription)")
                handleError(error)
            }
        }
    }
    
    private func requestRecordsInfo(_ op: RecordOperator) -> String {
        return switch op {
        case .allRecords:
            "Requesting all records."
        case .firstRecord:
            "Requesting first record."
        case .lastRecord:
            "Requesting last record."
        default:
            "Unknown request."
        }
    }
}

// MARK: - Private

private extension GlucoseViewModel {
    
    // MARK: listenToMeasurements()
    
    func listenToMeasurements(_ measurementCharacteristic: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        peripheral.listenValues(for: measurementCharacteristic)
            .compactMap { [log] data -> GlucoseMeasurement? in
                log.debug("Received Measurement Data \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) (\(data.count) bytes)")
                
                guard let parsed = try? GlucoseMeasurement(data) else {
                    log.error("Unable to parse Measurement Data \(data.hexEncodedString(options: [.upperCase, .twoByteSpacing]))")
                    return nil
                }
                
                log.info(parsed.newDataLog())
                return parsed
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [log] _ in
                log.debug("Completion")
            }, receiveValue: { [weak self] newValue in
                guard let self else { return }
                switch self.inFlightRequest {
                case .firstRecord:
                    self.firstRecord = newValue
                case .lastRecord:
                    self.lastRecord = newValue
                default:
                    self.allRecords.append(newValue)
                    refreshXDomain()
                    scrollPosition = max(-1, self.allRecords.endIndex-5) // GLS sequence number is 0, -1 is for padding
                }
            })
            .store(in: &cancellables)
    }

    private func refreshXDomain() {
        guard let first = allRecords.first else {
            minY = 0.0
            maxY = 0.4
            return
        }

        var minValue = first.measurement?.value ?? 0.0
        var maxValue = minValue
        var maxSequenceNumber = first.sequenceNumber
        for record in allRecords.dropFirst() {
            let value = record.measurement?.value ?? 0.0
            if value < minValue { minValue = value }
            if value > maxValue { maxValue = value }
            if record.sequenceNumber > maxSequenceNumber { maxSequenceNumber = record.sequenceNumber }
        }

        minY = minValue - 0.2
        maxY = maxValue + 0.2
        maxX = Double(maxSequenceNumber)
    }
    
    // MARK: processRACPResponse(:)
    
    @MainActor
    private func processRACPResponse(_ responseData: Data) throws {
        log.debug("\(type(of: self)).\(#function)")
        log.debug("RACP response: \(responseData.hexEncodedString(options: [.upperCase, .twoByteSpacing]))")
        let opcodeValue = responseData.littleEndianBytes(atOffset: 0, as: UInt8.self)
        let recordOpcode = RecordOpcode(rawValue: UInt8(opcodeValue))
        switch recordOpcode {
        case .responseCode:
            guard responseData.count >= 4 * MemoryLayout<UInt8>.size else {
                throw CriticalError.invalidRACPResponseCode
            }
            
            let targetOpcodeValue = responseData.littleEndianBytes(atOffset: 2, as: UInt8.self)
            let statusCode = responseData.littleEndianBytes(atOffset: 3, as: UInt8.self)
            guard let targetOpcode = RecordOpcode(rawValue: UInt8(targetOpcodeValue)) else { break }
            let status = RecordResponseStatus(rawValue: UInt8(statusCode))
            log.debug("Response Code for \(targetOpcode.description): \(status?.description ?? "Reserved for Future Use")")
        default:
            break
        }
    }
}

// MARK: - CustomStringConvertible

extension GlucoseMeasurement: @retroactive CustomStringConvertible {
    
    public var description: String {
        return String(format: "%.2f \(measurement?.unit.symbol ?? "NaN"), Seq.: \(sequenceNumber), Date: \(toStringDate()), Sensor: \(sensorString()), Location: \(locationString()), Status: \(statusString())", measurement?.value ?? "NaN")
    }
}

// MARK: - Error

extension GlucoseViewModel {
    
    enum CriticalError: LocalizedError {
        case cannotFindGlucoseMeasurementCCD
        case invalidRACPResponseCode
    }
}

// MARK: - CBUUID

extension CBUUID {
    
    static let glucoseService = CBUUID(service: .glucose)
}
