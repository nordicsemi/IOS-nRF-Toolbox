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

    // MARK: Private

    private func format(chunks: Int, bytes: Int) -> String {
        String(format: "%d chunks (%d B)", chunks, bytes)
    }

    // MARK: view

    var body: some View {
        LabeledContent {
            Text(viewModel.status.title)
        } label: {
            Label("Status", systemImage: viewModel.status.systemImage)
                .setAccent(viewModel.status.imageColor)
        }

        LabeledContent {
            Text(format(chunks: viewModel.pendingChunksCount, bytes: viewModel.pendingBytesCount))
        } label: {
            Label("Pending", systemImage: "clock.arrow.circlepath")
                .setAccent(Color.universalAccentColor)
        }

        LabeledContent {
            Text(format(chunks: viewModel.uploadedChunksCount, bytes: viewModel.uploadedBytesCount))
        } label: {
            Label("Uploaded", systemImage: "checkmark.icloud")
                .setAccent(Color.universalAccentColor)
        }
    }
}
