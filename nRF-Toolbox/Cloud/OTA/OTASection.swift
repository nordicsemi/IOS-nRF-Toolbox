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

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                header

                content
            }
            .padding(.vertical, 6)
            .animation(.smooth(duration: 0.35), value: stateKey)
        } header: {
            Text("Firmware Update")
        } footer: {
            footer
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, isActive: isWorking)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let installed = viewModel.installedVersion {
                VersionPill(version: installed, tint: .secondary)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            checkButton(title: "Check for Updates")
        case .checking:
            ProgressRow(text: "Looking for updates…")
        case .upToDate:
            if let updated = updatedBanner {
                updated
            }

            checkButton(title: "Check Again")
        case .available(let release):
            releaseCard(release)

            Button {
                viewModel.install(release)
            } label: {
                Label("Install \(release.version)", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.universalAccentColor)
        case .downloading(let release):
            releaseCard(release)

            ProgressRow(text: "Downloading firmware…")

            cancelButton
        case .updating(let step, let progress):
            UpdateProgress(step: step, progress: progress)

            cancelButton
        case .verifying:
            ProgressRow(text: "Device is restarting. Reading the new version…")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.nordicRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.nordicRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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

    // MARK: Pieces

    private func checkButton(title: String) -> some View {
        Button {
            viewModel.checkForUpdate(peripheral: peripheral, cloud: cloud)
        } label: {
            Label(title, systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(Color.universalAccentColor)
        .disabled(!cloud.isConfigured)
    }

    private var cancelButton: some View {
        Button(role: .cancel) {
            viewModel.cancel()
        } label: {
            Text("Cancel")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    private func releaseCard(_ release: CatalogRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VersionPill(version: viewModel.installedVersion ?? "–", tint: .secondary)

                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)

                VersionPill(version: release.version, tint: Color.universalAccentColor, emphasised: true)

                Spacer()
            }

            if !release.notes.trimmed.isEmpty {
                Text(release.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color.universalAccentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var updatedBanner: AnyView? {
        guard let to = viewModel.updatedToVersion else { return nil }
        let matches = viewModel.installedVersion == to
        let text = matches
            ? "Updated from \(viewModel.updatedFromVersion ?? "previous version") to \(to)"
            : "Update to \(to) was sent, but the device reports \(viewModel.installedVersion ?? "an unknown version")"
        let color: Color = matches ? Color.universalAccentColor : .orange
        return AnyView(
            Label(text, systemImage: matches ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
    }

    // MARK: Status

    private var stateKey: String {
        switch viewModel.state {
        case .idle: "idle"
        case .checking: "checking"
        case .upToDate: "upToDate"
        case .available: "available"
        case .downloading: "downloading"
        case .updating: "updating"
        case .verifying: "verifying"
        case .failed: "failed"
        }
    }

    private var isWorking: Bool {
        switch viewModel.state {
        case .checking, .downloading, .updating, .verifying: true
        default: false
        }
    }

    private var statusIcon: String {
        switch viewModel.state {
        case .idle: "cpu"
        case .checking: "magnifyingglass"
        case .upToDate: "checkmark.circle.fill"
        case .available: "arrow.down.circle.fill"
        case .downloading: "icloud.and.arrow.down.fill"
        case .updating: "arrow.triangle.2.circlepath"
        case .verifying: "power"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch viewModel.state {
        case .failed: Color.nordicRed
        case .idle: .secondary
        default: Color.universalAccentColor
        }
    }

    private var statusTitle: String {
        switch viewModel.state {
        case .idle: "Firmware"
        case .checking: "Checking for updates"
        case .upToDate: "Firmware is up to date"
        case .available(let release): "Version \(release.version) available"
        case .downloading: "Downloading"
        case .updating: "Updating firmware"
        case .verifying: "Finishing up"
        case .failed: "Something went wrong"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.state {
        case .idle: "Tap to look for a newer version"
        case .checking: "Comparing with your cloud releases"
        case .upToDate: "You have the latest version"
        case .available: "A newer release is ready to install"
        case .downloading: "Keep the app open"
        case .updating: "Do not disconnect or close the app"
        case .verifying: "Confirming the installed version"
        case .failed: "Check your connection and try again"
        }
    }
}

// MARK: - VersionPill

private struct VersionPill: View {

    let version: String
    var tint: Color
    var emphasised = false

    var body: some View {
        Text(version)
            .font(.system(.callout, design: .monospaced).weight(emphasised ? .bold : .regular))
            .foregroundStyle(emphasised ? Color.white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasised ? tint : tint.opacity(0.14))
            )
    }
}

// MARK: - ProgressRow

private struct ProgressRow: View {

    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - UpdateProgress

private struct UpdateProgress: View {

    let step: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let progress {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.subheadline, design: .monospaced))
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
        .padding(14)
        .background(Color.universalAccentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth, value: progress)
    }
}
