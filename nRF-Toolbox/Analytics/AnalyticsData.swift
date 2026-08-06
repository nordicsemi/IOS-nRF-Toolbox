//
//  AnalyticsData.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

enum Link: String {
    case logger = "LOGGER"
    case github = "GITHUB"
    case devZone = "DEV_ZONE"
}

enum Profile: String {
    case quickStart = "Quick Start"
    case bps = "Blood Pressure"
    case cgm = "Continuous Glucose"
    case channelSounding = "Channel Sounding"
    case csc = "Cycling Speed and Cadence"
    case ddfs = "Distance Measurement"
    case gls = "Glucose"
    case hrs = "Heart Rate"
    case hts = "Health Thermometer"
    case lbs = "LED Button"
    case rscs = "Running Speed and Cadence"
    case battery = "Battery"
    case throughput = "Throughput"
    case uart = "UART"
    case mds = "MDS"
    case dis = "Device Information"
    case dfu = "DFU"
}

enum UARTMode: String {
    case preset = "PRESET"
    case text = "TEXT"
}
