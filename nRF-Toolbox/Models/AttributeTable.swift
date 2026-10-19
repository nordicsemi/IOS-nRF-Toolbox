//
//  AttributeTable.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 12/07/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database

protocol StringIdentifiable  {
    var identifier: String { get }
}

struct AttributeTable {
    private(set) var services: [Service] = []
    
    var isEmpty: Bool { services.isEmpty }

    var signature: Set<String> {
        Set(services.flatMap { service in
            [service.uuidString] + service.characteristics.map { "\(service.uuidString)/\($0.uuidString)" }
        })
    }

    mutating func addService(_ cbService: CBService) {
        let service = Service(cbService: cbService)
        if let i = services.firstIndex(where: {
            $0.id == service.id
        }) {
            services[i] = service
        } else {
            services.append(service)
        }
//        services.replacedOrAppended(service, compareBy: \.identifier)
    }
    
    mutating func addCharacteristic(_ cbCharacteristic: CBCharacteristic, to service: CBService) {
        guard let serviceIndex = services.enumerated()
            .first(where: { $0.element.identifier == service.uuid.uuidString })?
            .offset else {
            return
        }
        
        let charateristic = Service.Characteristic(
            cbCharacteristic: cbCharacteristic
        )
        
        if let i = services[serviceIndex].characteristics.firstIndex(where: {
            $0.id == charateristic.id
        }) {
            services[serviceIndex].characteristics[i] = charateristic
        } else {
            services[serviceIndex].characteristics.append(charateristic)
        }
//        services[serviceIndex].characteristics.replacedOrAppended(charateristic, compareBy: \.identifier)
    }
    
    mutating func addDescriptor(_ cbDescriptor: CBDescriptor, to characteristic: CBCharacteristic, in service: CBService) {
        guard let serviceIndex = services.enumerated().first(where: { $0.element.identifier == service.uuid.uuidString })?.offset else { return }
                
        guard let characteristicIndex = services[serviceIndex].characteristics.enumerated().first(where: { $0.element.identifier == characteristic.uuid.uuidString })?.offset else { return }
        
        let descriptor = Service.Characteristic.Descriptor(
            cbDescriptor: cbDescriptor
        )
        
        if let i = services[serviceIndex].characteristics[characteristicIndex].descriptors.firstIndex(where: {
            $0.id == descriptor.id
        }) {
            services[serviceIndex].characteristics[characteristicIndex].descriptors[i] = descriptor
        } else {
            services[serviceIndex].characteristics[characteristicIndex].descriptors.append(descriptor)
        }
//        services[serviceIndex].characteristics[characteristicIndex].descriptors.replacedOrAppended(descriptor, compareBy: \.identifier)
    }
    
    var attributeList: [Attribute] {
        var list: [Attribute] = []
        
        for s in services {
            list.append(s)
            for c in s.characteristics {
                list.append(c)
                
                for d in c.descriptors {
                    list.append(d)
                }
            }
        }
        
        return list 
    }
    
    #if DEBUG
    func printAttributeList() {
        for attr in attributeList {
            let prefix = Array<String>(repeating: "-", count: Int(attr.level)).joined()
            print("|\(prefix): \(attr.name)")
        }
    }
    #endif
}

extension AttributeTable {
    struct Service: Identifiable, StringIdentifiable, Equatable, Attribute {
        typealias S = iOS_Bluetooth_Numbers_Database.Service
        
        var uuidString: String { cbService.uuid.uuidString }
        
        let cbService: CBService
        let id: String
        let identifier: String
        let name: String
        var level: UInt { 1 }
        var children: [Attribute] { characteristics }
        fileprivate(set) var characteristics: [Characteristic] = []
        
        init(cbService: CBService, id: String, identifier: String, name: String, characteristics: [Characteristic]) {
            self.cbService = cbService
            self.id = id
            self.identifier = identifier
            self.name = name
            self.characteristics = characteristics
        }
        
        init(cbService: CBService, defaultName: String = "Unknown Service") {
            self.cbService = cbService
            self.id = "s" + cbService.uuid.uuidString
            self.identifier = cbService.uuid.uuidString
            self.name = S.find(by: cbService.uuid)?.name ?? defaultName
        }
    }
}

extension AttributeTable.Service {
    struct Characteristic: Identifiable, StringIdentifiable, Equatable, Attribute {
        
        typealias C = iOS_Bluetooth_Numbers_Database.Characteristic
        
        var uuidString: String {
            cbCharacteristic.uuid.uuidString
        }
        
        
        let cbCharacteristic: CBCharacteristic
        let id: String
        let identifier: String
        let name: String
        var level: UInt { 2 }
        var children: [Attribute] { descriptors }
        fileprivate(set) var descriptors: [Descriptor] = []
        
        var prepertiesDescription: String {
            switch cbCharacteristic.properties {
            case [.read, .write, .notify]: return "RWN"
            case [.read, .write]: return "RW"
            case [.read, .notify]: return "RN"
            case [.read]: return "R"
            case [.write]: return "W"
            case [.notify]: return "N"
            default: return ""
            }
        }
        
        init(cbCharacteristic: CBCharacteristic, id: String, identifier: String, name: String, descriptors: [Descriptor]) {
            self.cbCharacteristic = cbCharacteristic
            self.id = id
            self.identifier = identifier
            self.name = name
            self.descriptors = descriptors
        }
        
        init(cbCharacteristic: CBCharacteristic, defaultName: String = "Unknown Characteristic") {
            self.cbCharacteristic = cbCharacteristic
            self.id = ((cbCharacteristic.service?.uuid.uuidString).map { "s" + $0 } ?? "") + "c" + cbCharacteristic.uuid.uuidString
            self.identifier = cbCharacteristic.uuid.uuidString
            self.name = C.find(by: cbCharacteristic.uuid)?.name ?? defaultName
        }
    }
}

extension AttributeTable.Service.Characteristic {
    struct Descriptor: Identifiable, StringIdentifiable, Equatable, Attribute {
        typealias D = iOS_Bluetooth_Numbers_Database.Descriptor
        
        let cbDescriptor: CBDescriptor
        let id: String
        let identifier: String
        let name: String
        var level: UInt { 3 }
        var children: [Attribute] { [] }
        
        var uuidString: String { cbDescriptor.uuid.uuidString }
        
        init(cbDescriptor: CBDescriptor, id: String, identifier: String, name: String) {
            self.cbDescriptor = cbDescriptor
            self.id = id
            self.identifier = identifier
            self.name = name
        }
        
        init(cbDescriptor: CBDescriptor, defaultName: String = "Unknown Descriptor") {
            self.cbDescriptor = cbDescriptor
            self.identifier = cbDescriptor.uuid.uuidString
            self.id = ((cbDescriptor.characteristic?.service?.uuid.uuidString).map { "s" + $0 } ?? "")
                + ((cbDescriptor.characteristic?.uuid.uuidString).map { "c" + $0 } ?? "")
                + "d" + cbDescriptor.uuid.uuidString
            
            self.name = D.find(by: cbDescriptor.uuid)?.name ?? defaultName
        }
    }
}

