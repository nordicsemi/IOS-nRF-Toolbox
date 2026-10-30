//
//  OTASection.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOSOtaLibrary
import iOS_Common_Libraries

struct OTASection: View {

    let viewModel: DeviceOTAViewModel
    let peripheral: UUID

    var body: some View {
        Section("Firmware Update") {
            switch viewModel.state {
            case .idle:
                checkButton
            case .checking:
                HStack {
                    Text("Checking for updates…")
                        .foregroundStyle(.secondary)

                    Spacer()

                    ProgressView()
                }
            case .upToDate:
                Label("Firmware is up to date", systemImage: "checkmark.circle")
                    .setAccent(Color.universalAccentColor)

                checkButton
            case .available(let release):
                releaseDetails(release)

                Button("Install Update") {
                    viewModel.install(release)
                }
                .foregroundStyle(Color.universalAccentColor)
            case .downloading(let release):
                releaseDetails(release)

                HStack {
                    Text("Downloading…")
                        .foregroundStyle(.secondary)

                    Spacer()

                    ProgressView()
                }

                Button("Cancel", role: .cancel) {
                    viewModel.cancel()
                }
            case .updating(let step, let progress):
                VStack(alignment: .leading, spacing: 8) {
                    Text(step)

                    if let progress {
                        ProgressView(value: progress)
                            .tint(Color.universalAccentColor)
                    } else {
                        IndeterminateProgressView()
                            .accentColor(.universalAccentColor)
                    }
                }
            case .completed:
                Label("Firmware updated", systemImage: "checkmark.circle")
                    .setAccent(Color.universalAccentColor)

                Button("Done") {
                    viewModel.reset()
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)

                Button("Retry") {
                    viewModel.checkForUpdate(peripheral: peripheral)
                }
            }
        }
    }

    private var checkButton: some View {
        Button("Check for Updates") {
            viewModel.checkForUpdate(peripheral: peripheral)
        }
        .foregroundStyle(Color.universalAccentColor)
    }

    @ViewBuilder
    private func releaseDetails(_ release: LatestReleaseInfo) -> some View {
        LabeledContent {
            Text(release.revision.isEmpty ? release.version : "\(release.version)-\(release.revision)")
        } label: {
            Label("Available", systemImage: "arrow.down.circle")
                .setAccent(Color.universalAccentColor)
        }

        if let artifact = release.artifacts.first {
            LabeledContent("Size", value: artifact.sizeString())
        }

        if !release.notes.trimmed.isEmpty {
            Text(release.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
