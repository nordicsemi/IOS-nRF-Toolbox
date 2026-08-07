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

    case description = """
You can help improve our application by sharing anonymous statistics on how you interact with the app. You can enable or disable this feature at any time in Settings.

**What kind of information do we collect?**

We collect only anonymous information about user interaction with the application. For example, we may measure how often a feature is used by counting the number of times the button that opens it is tapped.

Data provided by the user is never collected.

**How do we use this information?**

The information is used to analyze user interaction with the application and identify areas for improvement.

**How is this information processed and shared?**

Firebase is used to collect and process the data.

We do not share the data with any third-party companies or individuals other than Google (Firebase).
"""
}
