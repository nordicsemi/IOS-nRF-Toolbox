//
//  ObservabilityUnsupportedView.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - ObservabilityUnsupportedView

struct ObservabilityUnsupportedView: View {

    // MARK: view

    var body: some View {
        VStack(spacing: 16) {
            Image("device_manager")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(.nordicBlue)
                .frame(width: 56, height: 56)
            
            Text("MDS is not supported")
            
            Text("MDS service is not available in the current version of the app. Please use the nRF Connect Device Manager app from Nordic Semiconductor to update your device's firmware.")
                .font(.caption)
        }
    }
}
