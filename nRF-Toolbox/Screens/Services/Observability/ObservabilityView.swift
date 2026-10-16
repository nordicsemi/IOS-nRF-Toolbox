//
//  ObservabilityView.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - ObservabilityView

struct ObservabilityView: View {

    // MARK: Environment

    @Environment(ObservabilityViewModel.self) private var viewModel: ObservabilityViewModel

    // MARK: view

    var body: some View {
        HStack(spacing: 8) {
            Label("Status", systemImage: viewModel.status.systemImage)
                .setAccent(Color.universalAccentColor)
                .lineLimit(1)
                .layoutPriority(1)

            Text(viewModel.status.title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }

        LabeledContent {
            Text(viewModel.chunksInfo.pendingBytesString())
        } label: {
            Label("Pending", systemImage: "clock.arrow.circlepath")
                .setAccent(Color.universalAccentColor)
        }

        LabeledContent {
            Text(viewModel.chunksInfo.uploadedBytesString())
        } label: {
            Label("Uploaded", systemImage: "checkmark.icloud")
                .setAccent(Color.universalAccentColor)
        }
    }
}
