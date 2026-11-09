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
            VStack(alignment: .leading, spacing: 16) {
                header

                content
                    .animation(.smooth(duration: 0.35), value: phase)
            }
            .padding(.vertical, 6)
        } header: {
            Text("Firmware Update")
        } footer: {
            footer
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: phase.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(phase.tint)
                .symbolEffect(.pulse, isActive: phase.isWorking)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(Circle().fill(phase.tint.opacity(0.15)))
                .fixedSize()
                .animation(.smooth(duration: 0.3), value: phase.icon)
                .keyframeAnimator(initialValue: 1.0, trigger: phase.icon) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(0.8, duration: 0.15)
                        SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)

                Text(phase.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let installed = viewModel.installedVersion {
                VersionPill(version: installed, tint: .secondary)
            } else if isChecking {
                SkeletonBar(width: 56, height: 28)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle where isChecking, .checking:
            SkeletonCard()
        case .idle:
            checkButton(title: "Check for Updates")
        case .upToDate:
            updatedBanner

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
                .otaCard(Color.nordicRed, opacity: 0.1, radius: 12)

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
        .otaCard(Color.universalAccentColor)
    }

    @ViewBuilder
    private var updatedBanner: some View {
        if let to = viewModel.updatedToVersion {
            let matches = viewModel.installedVersion == to
            let text = matches
                ? "Updated from \(viewModel.updatedFromVersion ?? "previous version") to \(to)"
                : "Update to \(to) was sent, but the device reports \(viewModel.installedVersion ?? "an unknown version")"
            let color: Color = matches ? Color.universalAccentColor : .orange
            Label(text, systemImage: matches ? "checkmark.seal.fill" : "questionmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .otaCard(color, opacity: 0.1, radius: 12)
        }
    }

    // MARK: Status

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
