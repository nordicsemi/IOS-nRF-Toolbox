//
//  AnalyticsPermissionSwitchDialog.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - AnalyticsPermissionSwitchDialog

struct AnalyticsPermissionSwitchDialog: View {

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: Private

    @State private var isEnabled = NordicAnalytics.isAnalyticsEnabled()
    @State private var hasAnswered = !NordicAnalytics.needsPermission()

    // MARK: view

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AnalyticsHeroHeader(
                    icon: isEnabled ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis",
                    tint: isEnabled ? .nordicBlue : .nordicMiddleGrey,
                    title: AnalyticsString.switchTitle.rawValue,
                    subtitle: AnalyticsString.switchSubtitle.rawValue
                )
                .padding(.top, 8)

                statusCard

                AnalyticsInfoCards()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AnalyticsActionBar {
                Button(AnalyticsString.done.rawValue) {
                    dismiss()
                }
                .buttonStyle(AnalyticsFilledButtonStyle())
                .accessibilityIdentifier("analytics_done")
            }
        }
        .navigationTitle(AnalyticsString.switchTitle.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
        }
    }

    // MARK: status

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AnalyticsString.toggleTitle.rawValue)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .tint(.universalAccentColor)
            .accessibilityIdentifier("analytics_toggle")
            .padding(16)

            Divider()
                .padding(.leading, 16)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.footnote)
                    .foregroundStyle(isEnabled ? Color.nordicGrass : Color.nordicMiddleGrey)
                    .frame(width: 16)

                Text(statusDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .analyticsCardBackground()
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .onChange(of: isEnabled) { _, newValue in
            NordicAnalytics.setAnalyticsEnabled(newValue)
            hasAnswered = true
        }
    }

    private var statusIcon: String {
        guard hasAnswered else { return "questionmark.circle.fill" }
        return isEnabled ? "checkmark.circle.fill" : "slash.circle.fill"
    }

    private var statusDetail: LocalizedStringKey {
        guard hasAnswered else { return AnalyticsString.stateUndecidedDetail.rawValue }
        return isEnabled ? AnalyticsString.stateOnDetail.rawValue : AnalyticsString.stateOffDetail.rawValue
    }
}
