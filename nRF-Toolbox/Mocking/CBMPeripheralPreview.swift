//
//  CBMPeripheralPreview.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 17/07/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_BLE_Library_Mock
import CoreBluetoothMock

// MARK: - Constants

extension CBMUUID {
    static let nordicBlinkyService  = CBMUUID(string: "00001523-1212-EFDE-1523-785FEABCD123")
    static let buttonCharacteristic = CBMUUID(string: "00001524-1212-EFDE-1523-785FEABCD123")
    static let ledCharacteristic    = CBMUUID(string: "00001525-1212-EFDE-1523-785FEABCD123")
    
    static let heartRate            = CBMUUID(string: "180D")
    static let healthThermometer    = CBMUUID(string: "1809")
    static let bloodPressure        = CBMUUID(string: "1810")
    static let runningSpeedCadence  = CBMUUID(string: "1814")
    static let weightScale          = CBMUUID(string: "181D")
    static let cyclingSpeedCadence  = CBMUUID(string: "1816")
    static let deviceInformation    = CBMUUID(string: "180A")
    static let battery              = CBMUUID(string: "180F")
    static let quickStart           = CBMUUID(string: "B2007AAA-C203-43A5-8B6F-A7F3D001A1E0")
    static let memfaultDiagnostic   = CBMUUID(string: "54220000-F6A5-4007-A371-722F4EBD8436")
}

// MARK: - Services

extension CBMServiceMock {

    static let weightScale = CBMServiceMock(
        type: .weightScale,
        primary: true
    )
}

// MARK: - Blinky Implementation
struct MockConnectionError: Swift.Error {
    let title: String
    let message: String
}

private class WeightCBMPeripheralSpecDelegate: CBMPeripheralSpecDelegate {
    func peripheralDidReceiveConnectionRequest(_ peripheral: CBMPeripheralSpec) -> Result<Void, Swift.Error> {
        .failure(MockConnectionError(title: "Connection Error", message: "Failed to connect the peripheral"))
    }
}

// MARK: - Blinky Definition

let weightScale = CBMPeripheralSpec
    .simulatePeripheral(proximity: .immediate)
    .advertising(
        advertisementData: [
            CBAdvertisementDataIsConnectable : true as NSNumber,
            CBAdvertisementDataLocalNameKey : "Weight Scale",
            CBAdvertisementDataServiceUUIDsKey : [CBMUUID.weightScale]
        ],
        withInterval: 2.0,
        delay: 5.0,
        alsoWhenConnected: false
    )
    .connectable(
        name: "Weight Scale",
        services: [.weightScale],
        delegate: WeightCBMPeripheralSpecDelegate() // TODO: Change
    )
    .build()

//extension Peripheral {
//    static let preview: Peripheral = Peripheral(peripheral: CBMPeripheralPreview(hrm), delegate: ReactivePeripheralDelegate())
//}
