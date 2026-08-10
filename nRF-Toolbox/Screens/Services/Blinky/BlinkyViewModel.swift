//
//  BlinkyViewModel.swift
//  nRF Toolbox
//
//  Created by Dinesh Harjani on 5/6/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - BlinkyViewModel

@Observable
final class BlinkyViewModel: SupportedServiceViewModel {
    
    // MARK: Properties
    
    private let ledStream = CurrentValueSubject<Bool, Never>(false)
    var isLedOn = false {
        didSet {
            ledStream.send(isLedOn)
        }
    }
    
    private(set) var isButtonPressed: Bool = false
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var ledCharacteristics: CBCharacteristic!
    private var cancellables: Set<AnyCancellable>
    private var ledTask: Task<Void, Never>?
    private let log = NordicLog(category: "BlinkyViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.cancellables = Set<AnyCancellable>()
        self.characteristics = characteristics
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: description
    
    var description: String {
        "LED Button Service"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return BlinkyView()
            .environment(self)
    }
    
    // MARK: onConnect()
    
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("Blinky service has set up successfully.")
        } catch {
            log.error("Blinky service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    @MainActor
    private func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        
        let characteristics: [Characteristic] = [.nordicsemiBlinkyLedState, .nordicsemiBlinkyButtonState]
        let blinkyCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        guard let buttonCharacteristics = blinkyCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.nordicsemiBlinkyButtonState.uuid) else {
            log.error("Blinky button characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        guard let ledCharacteristics = blinkyCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.nordicsemiBlinkyLedState.uuid) else {
            log.error("Blinky LED characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        self.ledCharacteristics = ledCharacteristics
        
        if let initialValue = try await peripheral.readValue(for: buttonCharacteristics).firstValue {
            log.debug("peripheral.readValue(characteristic): \(initialValue.hexEncodedString(options: [.prepend0x, .twoByteSpacing]))")
            isButtonPressed = initialValue.littleEndianBytes(as: UInt8.self) > 0
        }
        
        listenToButtonPress(buttonCharacteristics)
        let isNotifyEnabled = try await peripheral.setNotifyValue(true, for: buttonCharacteristics).firstValue
        guard isNotifyEnabled else {
            log.error("Notifications not enabled.")
            throw ServiceError.notificationsNotEnabled
        }
        log.debug("peripheral.setNotifyValue(true, for: .nordicsemiBlinkyButtonState): \(isNotifyEnabled)")
        
        self.ledStream
            .dropFirst()
            .sink(receiveValue: { value in
                self.setLed(value)
            })
            .store(in: &cancellables)
    }
    
    private func setLed(_ newValue: Bool) {
        Task.detached { [weak self] in
            guard let self else { return }
            log.info("LED state changed to: \(newValue)")
            let data = Data(repeating: newValue ? 1 : 0, count: 1)
            
            log.debug("Sending new LED state \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing]))")
            _ = try? await peripheral.writeValueWithResponse(data, for: ledCharacteristics).firstValue
        }
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        ledTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: listenToButtonPress()
    
    func listenToButtonPress(_ characteristic: CBCharacteristic) {
        peripheral.listenValues(for: characteristic)
            .map { [weak self] data in
                self?.log.debug("Received button data: \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing]))")
                return data.littleEndianBytes(as: UInt8.self) > 0
            }
            .receive(on: DispatchQueue.main)
            .sink { completion in

            } receiveValue: { [weak self] value in
                self?.log.info("Button pressed: \(value)")
                self?.isButtonPressed = value
            }
            .store(in: &cancellables)
    }
}
