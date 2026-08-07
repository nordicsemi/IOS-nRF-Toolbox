//
//  AnalyticsPermissionRequestDialog.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - AnalyticsPermissionRequestDialog

struct AnalyticsPermissionRequestDialog: View {

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: view

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                AnalyticsHeroHeader(
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .nordicBlue,
                    title: AnalyticsString.title.rawValue,
                    subtitle: AnalyticsString.subtitle.rawValue
                )
                .padding(.top, 20)

                AnalyticsInfoCards()
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
            if NordicAnalytics.needsPermission() {
                NordicAnalytics.setAnalyticsEnabled(false)
            }
        }
    }

    // MARK: actions

    @ViewBuilder
    private var actions: some View {
        AnalyticsActionBar {
            Button(AnalyticsString.accept.rawValue) {
                answer(true)
            }
            .buttonStyle(AnalyticsFilledButtonStyle())
            .accessibilityIdentifier("analytics_accept")

            Button(AnalyticsString.decline.rawValue, role: .cancel) {
                answer(false)
            }
            .buttonStyle(AnalyticsPlainButtonStyle())
            .accessibilityIdentifier("analytics_decline")

            Text(AnalyticsString.footnote.rawValue)
                .font(.caption)
                .foregroundStyle(Color.nordicMiddleGrey)
                .multilineTextAlignment(.center)
        }
    }

    private func answer(_ enabled: Bool) {
        NordicAnalytics.setAnalyticsEnabled(enabled)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnalyticsPermissionRequestDialog()
    }
}
