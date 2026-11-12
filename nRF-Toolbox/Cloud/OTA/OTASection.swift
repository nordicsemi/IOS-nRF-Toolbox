//
//  OTASection.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct OTASection: View {

    @Environment(NRFCloudViewModel.self) private var cloud: NRFCloudViewModel

    let viewModel: DeviceOTAViewModel
    let peripheral: UUID
    var isConnected = true

    var body: some View {
        Section {
            status

            content
        } header: {
            Text("Firmware Update")
        } footer: {
            footer
        }
    }

    private var status: some View {
        LabeledContent {
            if let installed = viewModel.installedVersion {
                Text(installed)
                    .font(.callout.monospaced())
            } else if isChecking {
                ProgressView()
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)

                    Text(phase.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: phase.icon)
                    .foregroundStyle(phase.tint)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle where isChecking, .checking:
            EmptyView()
        case .idle:
            checkButton(title: "Check for Updates")
        case .upToDate:
            updatedBanner

            checkButton(title: "Check Again")
        case .available(let release):
            releaseRows(release)

            Button {
                viewModel.install(release)
            } label: {
                Label("Install \(release.version)", systemImage: "arrow.down.circle")
            }
            .foregroundStyle(Color.universalAccentColor)
        case .downloading(let release):
            releaseRows(release)

            ProgressRow(text: "Downloading firmware…")

            cancelButton
        case .updating(let step, let progress):
            UpdateProgress(step: step, progress: progress)

            cancelButton
        case .verifying:
            ProgressRow(text: "Device is restarting. Reading the new version…")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Color.nordicRed)

            checkButton(title: "Try Again")
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let date = viewModel.lastCheckedDate, !viewModel.isBusy {
            Text("Last checked \(date.formatted(.relative(presentation: .named)))")
        } else if !cloud.isConfigured {
            Text("Sign in and select a cloud project to check for firmware updates.")
        }
    }

    private func checkButton(title: String) -> some View {
        Button {
            viewModel.checkForUpdate(peripheral: peripheral, cloud: cloud)
        } label: {
            Label(title, systemImage: "arrow.clockwise")
        }
        .foregroundStyle(Color.universalAccentColor)
        .disabled(!cloud.isConfigured)
    }

    private var cancelButton: some View {
        Button("Cancel", role: .cancel) {
            viewModel.cancel()
        }
        .foregroundStyle(Color.nordicRed)
    }

    @ViewBuilder
    private func releaseRows(_ release: CatalogRelease) -> some View {
        LabeledContent("Available") {
            Text(release.version)
                .font(.callout.monospaced())
        }

        if !release.notes.trimmed.isEmpty {
            Text(release.notes)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var updatedBanner: some View {
        if let to = viewModel.updatedToVersion {
            let matches = viewModel.installedVersion == to
            let text = matches
                ? "Updated from \(viewModel.updatedFromVersion ?? "previous version") to \(to)"
                : "Update to \(to) was sent, but the device reports \(viewModel.installedVersion ?? "an unknown version")"
            Label(text, systemImage: matches ? "checkmark.seal" : "questionmark.circle")
                .foregroundStyle(matches ? Color.universalAccentColor : Color.nordicSun)
        }
    }

    private var isChecking: Bool {
        switch viewModel.state {
        case .checking: true
        case .idle: cloud.isConfigured && isConnected
        default: false
        }
    }

    private var phase: OTAPhase {
        isChecking ? .checking : OTAPhase(viewModel.state)
    }

    private var statusTitle: String {
        if case .available(let release) = viewModel.state, phase == .available {
            return "Version \(release.version) available"
        }
        return phase.title
    }
}
