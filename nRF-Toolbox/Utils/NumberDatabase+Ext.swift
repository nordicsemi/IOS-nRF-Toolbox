//
//  NumberDatabase+Ext.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 11/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Bluetooth_Numbers_Database
import SwiftUI
import iOS_BLE_Library_Mock
import iOS_Common_Libraries

// MARK: - Service Extension

extension Service {
    
    private static let serviceIcons: [Service : String] = [
        .runningSpeedAndCadence: "figure.run",
        .cyclingSpeedAndCadence: "figure.outdoor.cycle",
        .heartRate: "heart.fill",
        .batteryService: "battery.75percent",
        .bloodPressure: "drop.fill",
        .glucose: "syringe",
        .continuousGlucoseMonitoring: "syringe",
        .healthThermometer: "medical.thermometer",
        .nordicsemiLedAndButton: "lightbulb.max.fill",
        .throughputService: "metronome",
        .deviceInformation: "cpu",
        .nordicsemiUART: "character.cursor.ibeam",
        .quickStartService: "QuickStart",
        .memfaultMDS: "waveform.path.ecg"
    ]
    
    private static let colors: [Service : Color] = [
        .runningSpeedAndCadence: .cyan,
        .cyclingSpeedAndCadence: .green,
        .batteryService: .green,
        .heartRate: .red,
        .bloodPressure: .purple,
        .glucose: .orange,
        .continuousGlucoseMonitoring: .yellow,
        .healthThermometer: .indigo,
        .nordicsemiLedAndButton: .nordicBlue,
        .deviceInformation: .black,
        .throughputService: .nordicBlue,
        .nordicsemiUART: .nordicBlue,
        .quickStartService: .nordicPower,
        .memfaultMDS: .nordicBlueslate
    ]
    
    static var supportedServices: [Service] = [
        .runningSpeedAndCadence,
        .cyclingSpeedAndCadence,
        .nordicsemiLedAndButton,
        .heartRate,
        .bloodPressure,
        .glucose,
        .continuousGlucoseMonitoring,
        .nordicsemiUART,
        .healthThermometer,
        .batteryService,
        .deviceInformation,
        .throughputService,
        .quickStartService,
        .memfaultMDS
    ]
    
    var systemImage: Image? {
        guard let iconName = Service.serviceIcons[self] else { return nil }
        if self == .quickStartService {
            return Image(iconName)
                .renderingMode(.template)
        }
        return Image(systemName: iconName)
    }
    var color: Color? { Service.colors[self] }
    var isSupported: Bool { Service.supportedServices.contains(self) }
    
    // MARK: Init
    
    init(cbService: CBService, defaultName: String = "Unknown") {
        if let service = Service.find(by: cbService.uuid) {
            self = service
        } else {
            self = Service(name: defaultName, identifier: cbService.uuid.uuidString, uuidString: cbService.uuid.uuidString, source: "unknown")
        }
    }
}

// MARK: - Hashable

extension Service: @retroactive Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.uuidString)
    }
}

// MARK: - Identifiable

extension Service: @retroactive Identifiable {
    
    public var id: String {
        uuidString
    }
}
