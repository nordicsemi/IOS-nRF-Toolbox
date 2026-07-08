//
//  QuickStartViewModel.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - Service

public extension Service {

    static let quickStartService = Service(name: "Quick Start Service", identifier: "com.nordicsemi.service.quickstart", uuidString: "B2007AAA-C203-43A5-8B6F-A7F3D001A1E0", source: "nordic")
}

// MARK: - QuickStartViewModel

@Observable
final class QuickStartViewModel: SupportedServiceViewModel {

    // MARK: Properties

    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())

    // MARK: Private Properties

    private let log = NordicLog(category: "QuickStartViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    // MARK: init

    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        log.debug("\(type(of: self)).\(#function)")
    }

    // MARK: deinit

    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }

    // MARK: description

    var description: String {
        "Quick Start"
    }

    // MARK: attachedView

    var attachedView: any View {
        QuickStartView()
    }

    // MARK: onConnect() / onDisconnect()

    func onConnect() async { }

    func onDisconnect() { }
}
