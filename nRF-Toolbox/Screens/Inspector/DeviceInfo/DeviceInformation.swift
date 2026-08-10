//
//  DeviceInformation.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 06/02/2024.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import Combine
import SwiftUI
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - DeviceInformation

public struct DeviceInformation: CustomDebugStringConvertible {
    
    // MARK: CharacteristicInfo
    
    struct CharacteristicInfo: Identifiable {
        var id: String { name }
        var name: String
        var value: String
    }

    // MARK: Properties
    
    public var manufacturerName: String?
    public var modelNumber: String?
    public var serialNumber: String?
    public var hardwareRevision: String?
    public var firmwareRevision: String?
    public var softwareRevision: String?
    public var systemID: String?
    public var ieee11073: String?
    
    // MARK: init
    
    public init(_ characteristics: [CBCharacteristic], peripheral: Peripheral) async throws {
        var characteristicsByUUID = [CBUUID: CBCharacteristic](minimumCapacity: characteristics.count)
        for characteristic in characteristics {
            characteristicsByUUID[characteristic.uuid] = characteristic
        }

        func readString(_ characteristic: Characteristic) async throws -> String? {
            guard let c = characteristicsByUUID[CBUUID(string: characteristic.uuidString)],
                  let data = try await peripheral.readValue(for: c).firstValue else { return nil }
            return String(data: data, encoding: .utf8)
        }

        manufacturerName = try await readString(.manufacturerNameString)
        modelNumber = try await readString(.modelNumberString)
        serialNumber = try await readString(.serialNumberString)
        hardwareRevision = try await readString(.hardwareRevisionString)
        firmwareRevision = try await readString(.firmwareRevisionString)
        softwareRevision = try await readString(.softwareRevisionString)
        systemID = try await readString(.systemId)
        ieee11073 = try await readString(.ieee11073_20601RegulatoryCertificationDataList)
    }
    
    // MARK: debugDescription
    
    public var debugDescription: String {
        var s = ""
        if let manufacturerName {
            s += "Manufacturer: \(manufacturerName)\n"
        }
        if let modelNumber {
            s += "Model Number: \(modelNumber)\n"
        }
        if let serialNumber {
            s += "Serial Number: \(serialNumber)\n"
        }
        if let hardwareRevision {
            s += "Hardware Revision: \(hardwareRevision)\n"
        }
        if let firmwareRevision {
            s += "Firmware Revision: \(firmwareRevision)\n"
        }
        if let softwareRevision {
            s += "Software Revision: \(softwareRevision)\n"
        }
        if let systemID {
            s += "System ID: \(systemID)\n"
        }
        if let ieee11073 {
            s += "IEEE 11073: \(ieee11073)\n"
        }
        return s
    }

    // MARK: characteristics
    
    var characteristics: [CharacteristicInfo] {
        var c = [CharacteristicInfo]()
        if let manufacturerName {
            c.append(CharacteristicInfo(name: "Manufacturer", value: manufacturerName))
        }
        if let modelNumber {
            c.append(CharacteristicInfo(name: "Model Number", value: modelNumber))
        }
        if let serialNumber {
            c.append(CharacteristicInfo(name: "Serial Number", value: serialNumber))
        }
        if let hardwareRevision {
            c.append(CharacteristicInfo(name: "Hardware Revision", value: hardwareRevision))
        }
        if let firmwareRevision {
            c.append(CharacteristicInfo(name: "Firmware Revision", value: firmwareRevision))
        }
        if let softwareRevision {
            c.append(CharacteristicInfo(name: "Software Revision", value: softwareRevision))
        }
        if let systemID {
            c.append(CharacteristicInfo(name: "System ID", value: systemID))
        }
        if let ieee11073 {
            c.append(CharacteristicInfo(name: "IEEE 11073", value: ieee11073))
        }
        return c
    }
}
