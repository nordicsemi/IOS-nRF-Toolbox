//
//  ServiceDiscoveryProgressView.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 22/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - ServiceDiscoveryProgressView

struct ServiceDiscoveryProgressView: View {

    // MARK: Private Properties

    @State private var isPulsing = false

    // MARK: view

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.nordicBlue.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.15 : 0.85)
                    .opacity(isPulsing ? 0.4 : 1)

                Circle()
                    .fill(Color.nordicBlue.opacity(0.25))
                    .frame(width: 88, height: 88)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.nordicBlue)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Setting up your device")
                    .font(.title3.weight(.semibold))

                Text("Discovering services and preparing the connection. This usually takes a few seconds.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.nordicBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.secondarySystemBackground)
        .listRowSeparator(.hidden)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
