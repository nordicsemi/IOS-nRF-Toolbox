//
//  ThroughputData.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 28/1/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct ThroughputData {
    
    // MARK: Properties
    
    let numberOfWrites: UInt32
    private let bytesReceived: UInt32
    private let throughputBitsPerSecond: UInt32
    
    // MARK: Init
    
    init(_ data: Data) {
        guard data.count >= 3 * MemoryLayout<UInt32>.size,
              let numberOfWrites: UInt32 = try? data.read(fromOffset: 0),
              let bytesReceived: UInt32 = try? data.read(fromOffset: MemoryLayout<UInt32>.size),
              let throughputBitsPerSecond: UInt32 = try? data.read(fromOffset: 2 * MemoryLayout<UInt32>.size) else {
            self.numberOfWrites = 0
            self.bytesReceived = 0
            self.throughputBitsPerSecond = 0
            return
        }
        self.numberOfWrites = numberOfWrites
        self.bytesReceived = bytesReceived
        self.throughputBitsPerSecond = throughputBitsPerSecond
    }
    
    // MARK: API
    
    private static let naturalScaleFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        return formatter
    }()

    func bytesReceivedString() -> String {
        let measurement = Measurement<UnitInformationStorage>(value: Double(bytesReceived),
                                                              unit: .bytes)
        return Self.naturalScaleFormatter.string(from: measurement)
    }
    
    func bytesReceivedMeasurement() -> Measurement<UnitInformationStorage> {
        let measurement = Measurement<UnitInformationStorage>(value: Double(bytesReceived),
                                                              unit: .bytes)
        return measurement.converted(to: .kilobytes)
    }
    
    func throughputMeasurement() -> Measurement<UnitInformationStorage> {
        let measurement = Measurement<UnitInformationStorage>(value: Double(throughputBitsPerSecond),
                                                              unit: .bits)
        return measurement.converted(to: .kilobytes)
    }
}
