//
//  OTAComponents.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct ProgressRow: View {

    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

struct UpdateProgress: View {

    let step: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(step)

                Spacer()

                if let progress {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: progress))
                }
            }

            if let progress {
                ProgressView(value: progress)
                    .tint(Color.universalAccentColor)
            } else {
                IndeterminateProgressView()
                    .accentColor(.universalAccentColor)
            }
        }
        .animation(.smooth, value: progress)
    }
}
