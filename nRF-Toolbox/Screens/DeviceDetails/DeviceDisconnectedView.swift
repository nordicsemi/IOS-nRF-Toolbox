//
//  DeviceDisconnectedView.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 18/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import CoreBluetooth
import iOS_Common_Libraries

// MARK: - DeviceDisconnectedView

struct DeviceDisconnectedView: View {

    // MARK: view

    var body: some View {
        VStack(spacing: 24) {
            NoContentView(
                title: "Device disconnected",
                systemImage: "antenna.radiowaves.left.and.right.slash",
                description: "The connection with your device has been lost."
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.secondarySystemBackground)
        .listRowSeparator(.hidden)
    }

    // MARK: hint(_:_:)

    private func hint(_ systemImage: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.universalAccentColor)
        }
    }
}
