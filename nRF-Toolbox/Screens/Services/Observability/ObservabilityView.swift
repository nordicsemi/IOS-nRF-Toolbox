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
        LabeledContent {
            Text(viewModel.status.title)
        } label: {
            Label("Status", systemImage: viewModel.status.systemImage)
                .setAccent(Color.universalAccentColor)
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
