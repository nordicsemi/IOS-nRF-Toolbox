//
//  Throughput+Attributes.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 29/1/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Bluetooth_Numbers_Database
import CoreBluetoothMock
import iOS_BLE_Library_Mock

// MARK: - Service

public extension Service {
    
    static let throughputService = Service(name: "Throughput Service", identifier: "com.nordicsemi.service.throughput", uuidString: "0483DADD-6C9D-6CA9-5D41-03AD4FFF4ABB", source: "nordic")
    
    static let extendedServices: [Service] = [
        .throughputService,
        .quickStartService,
    ]
    
    static func extendedFind(by uuidString: String) -> Self? {
        if let standardFind = Service.find(by: CBUUID(string: uuidString)) {
            return standardFind
        }
        
        return extendedServices.first {
            CBUUID(string: $0.uuidString) == CBUUID(string: uuidString)
        }
    }
}

// MARK: - Characteristic

public extension Characteristic {
    
    static let throughputCharacteristic = Characteristic(
        name: "Throughput", identifier: "com.nordicsemi.characteristic.throughput",
        uuidString: "1524", source: "nordic")
}

// MARK: - CBUUID

public extension CBUUID {
    
    static let throughputService = CBUUID(service: .throughputService)
    
    static let throughputCharacteristic = CBUUID(characteristic: .throughputCharacteristic)
}
