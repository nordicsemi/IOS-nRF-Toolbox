//
//  AnalyticsString.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 07/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

enum AnalyticsString : String {
    case title = "Help us improve!"
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
