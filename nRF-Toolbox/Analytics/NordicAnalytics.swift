//
//  NordicAnalytics.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import FirebaseCore
import FirebaseAnalytics

class NordicAnalytics {
    
    static func configure() {
        FirebaseApp.configure()
    }
    
    static func logEvent(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
    
    static func setAnalyticsEnabled(_ enabled: Bool) {
        
    }
}
