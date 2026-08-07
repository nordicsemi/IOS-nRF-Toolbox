//
//  AnalyticsPermissionRequestDialog.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct AnalyticsPermissionRequestDialog: View {
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(AnalyticsString.title.rawValue)
                .font(.title)
            
            Spacer()
            
            if let attributedString = try? AttributedString(
                markdown: AnalyticsString.description.rawValue,
                options: .init(
                    interpretedSyntax: .full
                )
            ) {
                Text(attributedString)
                    .font(.footnote)
                    .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Decline", role: .cancel) {
                    dismiss()
                }
                .buttonStyle(BorederedButtonStyle())
                .foregroundColor(.nordicRed)
                
                Button("Accept") {
                    dismiss()
                }
                .buttonStyle(BorederedButtonStyle())
                .foregroundColor(.nordicBlue)
            }
            .padding()
        }
        .onDisappear {
            if NordicAnalytics.needsPermission() {
                NordicAnalytics.setAnalyticsEnabled(false)
            }
        }
    }
}
