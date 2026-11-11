//
//  NRFCloudReboot.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudReboot: Identifiable, Decodable, Equatable {
    
    let id: String
    let time: Date?
    let reasonCode: Int?
    let release: String?
    
    var reasonName: String {
        guard let reasonCode else { return "Unknown" }
        return Self.reasonNames[reasonCode] ?? "Reason 0x" + String(reasonCode, radix: 16, uppercase: true)
    }
    
    private enum CodingKeys: String, CodingKey {
        case time, reason
        case softwareVersion = "software_version"
    }
    
    private enum VersionKeys: String, CodingKey {
        case version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timeText = try? container.decode(String.self, forKey: .time)
        time = timeText.flatMap(Date.init(memfault:))
        reasonCode = try? container.decode(Int.self, forKey: .reason)
        release = (try? container.nestedContainer(keyedBy: VersionKeys.self, forKey: .softwareVersion))
            .flatMap { try? $0.decode(String.self, forKey: .version) }
        id = "\(timeText ?? "-")-\(reasonCode ?? -1)"
    }
    
    private static let reasonNames: [Int: String] = [
        0x0000: "Unknown",
        0x0001: "User Shutdown",
        0x0002: "User Reset",
        0x0003: "Firmware Update",
        0x0004: "Low Power",
        0x0005: "Debugger Halted",
        0x0006: "Button Reset",
        0x0007: "Power On Reset",
        0x0008: "Software Reset",
        0x0009: "Deep Sleep",
        0x000A: "Pin Reset",
        0x000B: "Self Test",
        0x8000: "Unknown Error",
        0x8001: "Assert",
        0x8002: "Watchdog",
        0x8003: "Brown Out Reset",
        0x8004: "Non-Maskable Interrupt",
        0x8005: "Hardware Watchdog",
        0x8006: "Software Watchdog",
        0x8007: "Clock Failure",
        0x8008: "Kernel Panic",
        0x8009: "Firmware Update Error",
        0x800A: "Out Of Memory",
        0x800B: "Stack Overflow",
        0x800C: "Task Watchdog",
        0x9100: "Bus Fault",
        0x9200: "Mem Fault",
        0x9300: "Usage Fault",
        0x9400: "Hard Fault",
        0x9401: "Lockup",
        0x9402: "Security Violation",
        0x9403: "Parity Error",
        0x9404: "Temperature",
        0x9405: "Hardware"
    ]
}
