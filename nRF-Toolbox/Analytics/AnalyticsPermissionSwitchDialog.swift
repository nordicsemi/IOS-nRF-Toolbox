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
            
            Text(AnalyticsString.description.rawValue)
                .font(.footnote)
                .padding()
            
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
