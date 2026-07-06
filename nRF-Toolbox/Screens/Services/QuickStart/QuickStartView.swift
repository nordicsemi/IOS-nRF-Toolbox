//
//  QuickStartView.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - QuickStartView

struct QuickStartView: View {

    // MARK: view

    var body: some View {
        VStack {
            Image("nrf54dk")
                .resizable()
                .scaledToFit()
                .padding()
                .padding(.horizontal, 16)
            
            Text("Congratulations! You have successfully connected to the Bluetooth Quick Start sample on nRF54L15DK.")
                .font(.caption)
        }
    }
}
