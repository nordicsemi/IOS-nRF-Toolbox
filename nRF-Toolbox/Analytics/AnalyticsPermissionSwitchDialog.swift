//
//  AnalyticsPermissionSwitchDialog.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct AnalyticsPermissionSwitchDialog: View {

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: view

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 12) {
                    InfoCard(
                        icon: "hand.tap.fill",
                        tint: .nordicBlue,
                        title: AnalyticsString.collectTitle.rawValue,
                        message: AnalyticsString.collectBody.rawValue
                    )

                    InfoCard(
                        icon: "lightbulb.fill",
                        tint: .nordicSun,
                        title: AnalyticsString.useTitle.rawValue,
                        message: AnalyticsString.useBody.rawValue
                    )

                    InfoCard(
                        icon: "lock.shield.fill",
                        tint: .nordicGrass,
                        title: AnalyticsString.shareTitle.rawValue,
                        message: AnalyticsString.shareBody.rawValue
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // Covers the swipe-to-dismiss case: no answer means no tracking.
            if NordicAnalytics.needsPermission() {
                NordicAnalytics.setAnalyticsEnabled(false)
            }
        }
    }

    // MARK: header

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.nordicBlue.opacity(0.12))

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.nordicBlue)
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 8) {
                Text(AnalyticsString.title.rawValue)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(AnalyticsString.subtitle.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }

    // MARK: actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            Button(AnalyticsString.accept.rawValue) {
                answer(true)
            }
            .buttonStyle(FilledActionButtonStyle())
            .accessibilityIdentifier("analytics_accept")

            Button(AnalyticsString.decline.rawValue, role: .cancel) {
                answer(false)
            }
            .buttonStyle(PlainActionButtonStyle())
            .accessibilityIdentifier("analytics_decline")

            Text(AnalyticsString.footnote.rawValue)
                .font(.caption)
                .foregroundStyle(Color.nordicMiddleGrey)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func answer(_ enabled: Bool) {
        NordicAnalytics.setAnalyticsEnabled(enabled)
        dismiss()
    }
}

// MARK: - InfoCard

private struct InfoCard: View {

    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: - Button Styles

private struct FilledActionButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.universalAccentColor)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PlainActionButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.nordicMiddleGrey)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
