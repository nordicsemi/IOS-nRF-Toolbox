//
//  AnalyticsHelper.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import CoreBluetoothMock

class AnalyticsHelper {
    
    static func onServiceDiscovered(uuid: CBMUUID) {
        switch uuid {
        case .nordicBlinkyService:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .lbs))
        case .quickStart:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .quickStart))
        case .memfaultDiagnostic:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .mds))
        case .runningSpeedCadence:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .rscs))
        case .cyclingSpeedCadence:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .csc))
        case .healthThermometer:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .hts))
        case .heartRate:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .hrs))
        case .bloodPressure:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .bps))
        case .battery:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .battery))
        case .throughputService:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .throughput))
        case .glucoseService:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .gls))
        case .continuousGlucoseMonitoringService:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .cgm))
        case .nordicsemiUART:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .uart))
        case .deviceInformation:
            NordicAnalytics.logEvent(ProfileConnectedEvent(profile: .dis))
        default:
            break
        }
    }
}
