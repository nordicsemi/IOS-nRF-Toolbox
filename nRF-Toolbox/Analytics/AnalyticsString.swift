//
//  AnalyticsString.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 07/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

enum AnalyticsString : LocalizedStringKey {
    case title = "Help us improve!"
    case subtitle = "Share anonymous usage statistics so we know which parts of nRF Toolbox deserve our attention."

    case collectTitle = "What we collect"
    case collectBody = "Only anonymous interaction data — for example, how often a feature is opened. Data you provide or receive from your devices is never collected."

    case useTitle = "How we use it"
    case useBody = "To understand how the app is used and to find the areas that need improvement."

    case shareTitle = "Where it goes"
    case shareBody = "Firebase collects and processes the data. We never share it with anyone other than Google (Firebase)."

    case footnote = "You can turn this on or off at any time in Settings."

    case accept = "Share statistics"
    case decline = "Not now"

    // MARK: Switch dialog

    case switchTitle = "Usage Statistics"
    case switchSubtitle = "Change your mind at any time — this only affects anonymous statistics."

    case toggleTitle = "Share anonymous statistics"
    case stateOn = "On"
    case stateOff = "Off"

    case stateOnDetail = "You allowed anonymous statistics. Turning this off stops collection immediately."
    case stateOffDetail = "You declined anonymous statistics. Nothing is being collected."
    case stateUndecidedDetail = "You haven't made a choice yet. Statistics are off until you turn them on."

    case done = "Done"
}
