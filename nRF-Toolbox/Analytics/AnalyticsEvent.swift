//
//  AnalyticsEvent.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

class AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    
    init(name: String, parameters: [String : Any]) {
        self.name = name
        self.parameters = parameters
    }
}

class AppOpenEvent : AnalyticsEvent {
    
    init() {
        super.init(name: "APP_OPEN", parameters: [:])
    }
}

class LinkOpenEvent : AnalyticsEvent {
    
    init(link: Link) {
        super.init(name: "LINK_OPEN", parameters: ["LINK" : link.rawValue])
    }
}

class ProfileConnectedEvent : AnalyticsEvent {
    
    init(profile: Profile) {
        super.init(name: "PROFILE_CONNECTED", parameters: ["PROFILE_NAME" : profile.rawValue])
    }
}

class UARTSendEvent : AnalyticsEvent {
    
    init(mode: UARTMode) {
        super.init(name: "UART_SEND_EVENT", parameters: ["PROFILE_NAME" : mode.rawValue])
    }
}

class UARTCreateConfigurationEvent : AnalyticsEvent {
    
    init() {
        super.init(name: "UART_CREATE_CONF", parameters: [:])
    }
}

class UARTChangeConfigurationEvent : AnalyticsEvent {
    
    init() {
        super.init(name: "UART_CHANGE_CONF", parameters: [:])
    }
}
