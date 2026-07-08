//
//  Device.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 08/07/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Bluetooth_Numbers_Database

struct Device: Identifiable, CustomStringConvertible, CustomDebugStringConvertible, Hashable, Equatable {
    
    // MARK: Status
    
    enum Status: CustomStringConvertible {
        case connected
        case connecting
        case userInitiatedDisconnection
        case error(_: Error)

        var description: String {
            switch self {
            case .connected:
                return "Connected"
            case .connecting:
                return "Connecting"
            case .userInitiatedDisconnection:
                return "User initiated disconnection"
            case .error(let error):
                return "Error: \(error.localizedDescription)"
            }
        }

        var hashValue: Int {
            switch self {
            case .connected:
                return 0
            case .userInitiatedDisconnection:
                return 1
            case .connecting:
                return 2
            case .error:
                return 99
            }
        }
    }
    
    // MARK: Properties
    
    let name: String?
    let id: UUID
    var services: Set<Service>
    var status: Status
    var description: String { name ?? "Unnamed" }
    var debugDescription: String { description }
    
    var logName: String {
        "Device(name: \(description), id: \(id))"
    }
    
    // MARK: init
    
    init(name: String?, id: UUID, services: Set<Service>, status: Status) {
        self.name = name
        self.id = id
        self.services = services
        self.status = status
    }
    
    // MARK: Equatable

    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.id == rhs.id
            && lhs.status.hashValue == rhs.status.hashValue
            && lhs.services == rhs.services
            && lhs.name == rhs.name
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status.hashValue)
        hasher.combine(services)
        hasher.combine(name)
    }
}
