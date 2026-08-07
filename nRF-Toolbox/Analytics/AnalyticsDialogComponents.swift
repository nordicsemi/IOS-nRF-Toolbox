//
//  AnalyticsDialogComponents.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 07/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - AnalyticsHeroHeader

struct AnalyticsHeroHeader: View {

    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - AnalyticsInfoCards

struct AnalyticsInfoCards: View {

    var body: some View {
        VStack(spacing: 12) {
            AnalyticsInfoCard(
                icon: "hand.tap.fill",
                tint: .nordicBlue,
                title: AnalyticsString.collectTitle.rawValue,
                message: AnalyticsString.collectBody.rawValue
            )

            AnalyticsInfoCard(
                icon: "lightbulb.fill",
                tint: .nordicSun,
                title: AnalyticsString.useTitle.rawValue,
                message: AnalyticsString.useBody.rawValue
            )

            AnalyticsInfoCard(
                icon: "lock.shield.fill",
                tint: .nordicGrass,
                title: AnalyticsString.shareTitle.rawValue,
                message: AnalyticsString.shareBody.rawValue
            )
        }
    }
}

// MARK: - AnalyticsInfoCard

struct AnalyticsInfoCard: View {

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
        .analyticsCardBackground()
    }
}

// MARK: - Card Background

extension View {

    func analyticsCardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: - Button Styles

struct AnalyticsFilledButtonStyle: ButtonStyle {

    var background: Color = .universalAccentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AnalyticsPlainButtonStyle: ButtonStyle {

    var foreground: Color = .nordicMiddleGrey

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Bottom Action Bar

struct AnalyticsActionBar<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
