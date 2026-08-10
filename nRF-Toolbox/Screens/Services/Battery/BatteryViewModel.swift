//
//  BatteryViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 4/12/24.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - BatteryViewModel

@Observable
final class BatteryViewModel: SupportedServiceViewModel {
    
    // MARK: Properties
    
    fileprivate(set) var batteryLevelData: [ChartTimeData<Battery.Level>]
    fileprivate(set) var currentBatteryLevel: UInt?
    fileprivate(set) var batteryLevelAvailable: Bool
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var cancellables: Set<AnyCancellable>
    private let log = NordicLog(category: "BatteryViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    
    private static let batteryLevelDataLength = 120
    private static let batteryLevelRange: ClosedRange<UInt> = 0...100
    
    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.characteristics = characteristics
        self.cancellables = Set<AnyCancellable>()
        self.batteryLevelData = []
        self.currentBatteryLevel = nil
        self.batteryLevelAvailable = false
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // initializeCharacteristics()
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let characteristics: [Characteristic] = [.batteryLevel]
        let cbCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        // Check if `batteryLevel` characteristic was discovered
        guard let cbBatteryLevel = cbCharacteristics.first, cbBatteryLevel.uuid == Characteristic.batteryLevel.uuid else {
            throw ServiceError.noMandatoryCharacteristic
        }
        
        batteryLevelAvailable = true
        do {
            listen(for: cbBatteryLevel)
            let turnOnNotifications = try await peripheral.setNotifyValue(true, for: cbBatteryLevel)
                .timeout(1, scheduler: DispatchQueue.main)
                .firstValue
            log.debug("peripheral.setNotifyValue(true, for: cbBatteryLevel)")
        } catch {
            // Read in case of error.
            try? await readBatteryLevelOnTimer(cbBatteryLevel)
        }
    }
    
    // MARK: listen(for:)
    
    private func listen(for batteryLevelCh: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        let publisher = peripheral.listenValues(for: batteryLevelCh)
            .eraseToAnyPublisher()
        
        handleBatteryPublisher(publisher)
    }
    
    // MARK: readBatteryLevelOnTimer()
    
    private func readBatteryLevelOnTimer(_ batteryLevelCh: CBCharacteristic, timeInterval: TimeInterval = 1) async throws {
        log.debug("\(type(of: self)).\(#function)")
        let publisher = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .flatMap { [unowned self] _ in
                self.log.debug("Timer { peripheral.readValue(for: batteryLevelCh) }")
                return self.peripheral.readValue(for: batteryLevelCh)
            }
            .compactMap { $0 }
            .eraseToAnyPublisher()

        handleBatteryPublisher(publisher)
    }
    
    // MARK: handleBatteryPublisher()
    
    private func handleBatteryPublisher(_ publisher: AnyPublisher<Data, Error>) {
        publisher
            .map {
                let batteryLevel = $0.littleEndianBytes(as: UInt8.self)
                return Battery.Level(level: min(UInt(batteryLevel), Self.batteryLevelRange.upperBound))
            }
            .map { ChartTimeData<Battery.Level>(value: $0) }
            .scan(Array<ChartTimeData<Battery.Level>>(), { result, lvl in
                var res = result
                res.append(lvl)
                if res.count > Self.batteryLevelDataLength {
                    res.removeFirst()
                }
                return res
            })
            .receive(on: DispatchQueue.main)
            .sink { completion in

            } receiveValue: { [unowned self] level in
                var lvlData = level
                while lvlData.count < Self.batteryLevelDataLength {
                    let date = (lvlData.last?.date).map { Date(timeInterval: 1, since: $0) } ?? Date()
                    lvlData.append(.init(value: 0, date: date))
                }
                
                currentBatteryLevel = level.last?.value.level
                batteryLevelData = lvlData
            }
            .store(in: &cancellables)
    }
    
    // MARK: description
    
    var description: String {
        "Battery"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return BatteryView()
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
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        cancellables.removeAll()
    }
}
