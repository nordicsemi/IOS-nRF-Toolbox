//
//  HeartRateViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 25/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Combine 
import SwiftUI
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - HeartRateViewModel
@Observable
final class HeartRateViewModel: @MainActor SupportedServiceViewModel {
    
    fileprivate(set) var data: [HeartRateValue] = []
    fileprivate(set) var location: HeartRateMeasurement.SensorLocation?
    fileprivate(set) var caloriesResetState = CaloriesResetState.unavailable
    var scrollPosition = Date()
    private(set) var minDate: Date = .distantPast
    private(set) var maxDate: Date = .distantFuture
    
    fileprivate(set) var criticalError: ServiceError?
    var alertError: Error?

    fileprivate(set) var lowest: Int = 40
    fileprivate(set) var highest: Int = 200
    
    let visibleDomain = 60
    private let capacity = 360
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var hrMeasurement: CBCharacteristic!
    private var heartRateControlPoint: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()
    
    private let log = NordicLog(category: "HeartRateViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    fileprivate var internalAlertError: ServiceWarning? {
        didSet {
            alertError = internalAlertError
        }
    }
    
    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.data = []
        self.criticalError = nil
        self.alertError = nil
        self.characteristics = characteristics
        self.data.reserveCapacity(capacity)
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: description
    
    var description: String {
        "Heart Monitor"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return HeartRateView()
            .environment(self)
    }
    
    // MARK: onConnect()
    
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Heart Rate service has set up successfully.")
        } catch {
            log.error("Heart Rate service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
//        await notifyHRMeasurement(false)
        cancellables.removeAll()
    }
}

// MARK: - Private

private extension HeartRateViewModel {
    
    // MARK: initializeCharacteristics()
    
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let hrCharacteristics: [Characteristic] = [.heartRateMeasurement, .bodySensorLocation, .heartRateControlPoint]
        
        let heartRateCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            hrCharacteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        hrMeasurement = heartRateCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.heartRateMeasurement.uuid)
        guard hrMeasurement != nil else {
            log.error("Heart Rate Measurement characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        try await notifyHRMeasurement(true)
        // in case of success - listen
        listenTo(hrMeasurement)
        
        guard let bodySensorCharacteristic = heartRateCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.bodySensorLocation.uuid) else { return }
        
        log.debug("Found Body Sensor Characteristic")
        location = try? await peripheral.readValue(for: bodySensorCharacteristic).tryMap { data in
            guard let data, data.canRead(UInt8.self, atOffset: 0) else {
                throw ServiceError.unknown
            }
            
            self.log.debug("Received location data: \(data.hexEncodedString(options: [.upperCase, .twoByteSpacing]))")
            
            return HeartRateMeasurement.SensorLocation(rawValue: RegisterValue(data[0]))
        }
        .timeout(.seconds(1), scheduler: DispatchQueue.main, customError: {
            ServiceError.unknown
        })
        .firstValue

        if let location {
            log.info("Body Sensor Location: \(location.description)")
        }
        
        heartRateControlPoint = heartRateCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.heartRateControlPoint.uuid)
        if heartRateControlPoint != nil {
            log.info("Found Heart Rate Control Point Characteristic")
            caloriesResetState = .available
        }
    }
    
    // MARK: listenTo()
    
    func listenTo(_ characteristic: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        peripheral.listenValues(for: characteristic)
            .compactMap { data in
                self.log.debug("Received measurement data: \(data.hexEncodedString(options: [.upperCase, .twoByteSpacing]))")
                
                let result = try? HeartRateValue(with: data)
                if let result {
                    self.log.info(result.newDataLog())
                }
              
                return result
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure = completion {
                    self.internalAlertError = ServiceWarning.measurement
                }
            } receiveValue: { [unowned self] newValue in
                let diff = newValue.date.timeIntervalSince1970 - scrollPosition.timeIntervalSince1970
                if diff < CGFloat(visibleDomain + 5) || data.isEmpty {
                    scrollPosition = .now
                }

                data.append(newValue)
                if data.count > capacity {
                    data.removeFirst()
                }

                recalculateDomains()
            }
            .store(in: &cancellables)
    }
    
    // MARK: notifyHRMeasurement()
    @MainActor
    func notifyHRMeasurement(_ enable: Bool) async throws {
        guard let hrMeasurement else { return }
        log.debug("\(type(of: self)).\(#function)")
        do {
            let result = try await peripheral.setNotifyValue(enable, for: hrMeasurement).firstValue
            log.debug("Enabled HR Measurement Characteristic: \(result)")
        } catch {
            log.error(error.localizedDescription)
            handleError(error)
        }
    }

    private func recalculateDomains() {
        guard let first = data.first, let last = data.last else {
            lowest = 40
            highest = 200
            minDate = .distantPast
            maxDate = .distantFuture
            return
        }

        var minValue = first.measurement.heartRateValue
        var maxValue = minValue
        for item in data.dropFirst() {
            let value = item.measurement.heartRateValue
            if value < minValue { minValue = value }
            if value > maxValue { maxValue = value }
        }

        lowest = minValue - 5
        highest = maxValue + 5
        minDate = first.date.addingTimeInterval(-5)
        maxDate = last.date.addingTimeInterval(5)
    }
}

// MARK: - Actions

extension HeartRateViewModel {
    
    @MainActor
    func resetMeasurement() {
        Task {
            if let heartRateControlPoint {
                log.info("Resetting energy counter...")
                do {
                    self.errors.value.warning = nil
                    caloriesResetState = .inProgress
                    let command: [UInt8] = [0x01]  // Reset calories counter
                    let data = Data(command)
                    try await peripheral.writeValueWithResponse(data, for: heartRateControlPoint)
                        .firstValue
                    caloriesResetState = .available
                    log.info("Successfully reset energy counter.")
                } catch {
                    caloriesResetState = .available
                    self.errors.value.warning = ServiceWarning.unknown
                    log.error("Reset energy counter - error: \(error)")
                }
            } else {
                log.error("heartRateControlPoint is nil. Cannot reset measurement.")
            }
        }
    }
    
    func clearControlPointError() {
        caloriesResetState = .available
    }
}
