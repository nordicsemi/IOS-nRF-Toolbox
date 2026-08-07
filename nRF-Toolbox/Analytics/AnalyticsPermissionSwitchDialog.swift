//
//  AnalyticsPermissionSwitchDialog.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct AnalyticsPermissionSwitchDialog: View {
    @State private var showDialog = false

    var body: some View {
        HStack {
            Text(AnalyticsString.title.rawValue)
            
            if let attributedString = try? AttributedString(
                markdown: AnalyticsString.description.rawValue
            ) {
                Text(attributedString)
            }
            
            VStack {
                Button("Options") {
                    showDialog = true
                }
                
                Button("Options") {
                    showDialog = true
                }
            }
        }
    }
}
