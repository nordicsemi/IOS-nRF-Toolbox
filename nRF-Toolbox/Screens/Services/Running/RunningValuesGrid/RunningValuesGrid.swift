//
//  RunningValuesGrid.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 18/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

private typealias Env = RunningServiceViewModel.Environment

// MARK: - RunningAttribute

struct RunningAttribute: Identifiable {
    let title: String
    let value: String
    let unit: String?
    
    var id: String {
        title
    }
}

// MARK: - RunningValuesGrid

struct RunningValuesGrid: View {
    
    // MARK: Environment
    
    @Environment(Env.self) private var environment: Env
    
    // MARK: view
    
    var body: some View {
        NumberedColumnGrid(columns: 2, data: items) { item in
            RunningValuesGridItem(title: item.title, value: item.value, unit: item.unit)
        }
    }
}

// MARK: - Private

private extension RunningValuesGrid {

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var items: [RunningAttribute] {
        let numberFormatter = Self.numberFormatter

        var items = [RunningAttribute]()
        
        let speedKey = "Speed"
        if let speed = environment.instantaneousSpeed {
            items.append(RunningAttribute(
                title: speedKey,
                value: numberFormatter.string(from: NSNumber(floatLiteral: speed.value)) ?? "-.-",
                unit: speed.unit.symbol))
        } else {
            items.append(itemPlaceholder(speedKey))
        }
        
        let cadenceKey = "Cadence"
        if let cadence = environment.instantaneousCadence {
            items.append(RunningAttribute(
                title: cadenceKey,
                value: "\(cadence)",
                unit: "steps/min"))
        } else {
            items.append(itemPlaceholder(cadenceKey))
        }
        
        if environment.features.contains(.instantaneousStrideLengthMeasurement) {
            let strideLengthKey = "Stride Length"
            if let instantaneousStrideLength = environment.instantaneousStrideLength {
                items.append(RunningAttribute(
                    title: strideLengthKey,
                    value: numberFormatter.string(from: NSNumber(floatLiteral: instantaneousStrideLength.value)) ?? "-.-",
                    unit: instantaneousStrideLength.unit.symbol))
            } else {
                items.append(itemPlaceholder(strideLengthKey))
            }
        }
        
        if environment.features.contains(.totalDistanceMeasurement) {
            let totalDistanceKey = "Total Distance"
            
            if let totalDistance = environment.totalDistance {
                items.append(RunningAttribute(
                    title: totalDistanceKey,
                    value: numberFormatter.string(from: NSNumber(floatLiteral: totalDistance.value)) ?? "-.-",
                    unit: totalDistance.unit.symbol))
            } else {
                items.append(itemPlaceholder(totalDistanceKey))
            }
        }
        
        if environment.features.contains(.walkingOrRunningStatus) {
            let walkingRunningStatusKey = "Walking / Running"
         
            if let walkingRunning = environment.isRunning {
                let status: String = walkingRunning ? "Running" : "Walking"
                let emoji = walkingRunning ? "🏃" : "🚶"
                items.append(
                    RunningAttribute(title: walkingRunningStatusKey, value: emoji, unit: status)
                )
            } else {
                items.append(
                    RunningAttribute(title: walkingRunningStatusKey, value: "-", unit: nil)
                )
            }
        }
        
        return items
    }
    
    func itemPlaceholder(_ key: String) -> RunningAttribute {
        return RunningAttribute(title: key, value: "-.-", unit: "-")
    }
}
