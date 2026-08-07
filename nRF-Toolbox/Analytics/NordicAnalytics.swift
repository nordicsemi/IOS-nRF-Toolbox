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
    
    private static let isEnabledKey = "analytics.enabled"
    private static let storage = UserDefaults(suiteName: "analytics")!
    private static var hasBeenConfigured = false
    
    static func configure() {
        guard storage.bool(forKey: isEnabledKey) else { return }
        FirebaseApp.configure()
        hasBeenConfigured = true
        logEvent(AppOpenEvent())
    }
    
    static func logEvent(_ event: AnalyticsEvent) {
        guard storage.bool(forKey: isEnabledKey) else { return }
        if !hasBeenConfigured {
            FirebaseApp.configure()
            hasBeenConfigured = true
        }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
    
    static func setAnalyticsEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
        storage.set(enabled, forKey: isEnabledKey)
    }
    
    static func isAnalyticsEnabled() -> Bool {
        return storage.bool(forKey: isEnabledKey)
    }
    
    static func needsPermission() -> Bool {
        return storage.object(forKey: isEnabledKey) == nil
    }
}
