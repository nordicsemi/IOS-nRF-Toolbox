//
//  OTAComponents.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 29/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

extension View {

    func otaCard(_ color: Color, opacity: Double = 0.08, radius: CGFloat = 14) -> some View {
        background(color.opacity(opacity), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct VersionPill: View {

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

struct ProgressRow: View {

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
        .otaCard(Color.secondary, radius: 12)
    }
}

struct UpdateProgress: View {

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
        .otaCard(Color.universalAccentColor)
        .animation(.smooth, value: progress)
    }
}

struct SkeletonBar: View {

    var width: CGFloat?
    var height: CGFloat = 14

    @State private var dimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.secondary.opacity(dimmed ? 0.12 : 0.28))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

struct SkeletonCard: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SkeletonBar(width: 64, height: 28)

                SkeletonBar(width: 18, height: 10)

                SkeletonBar(width: 64, height: 28)

                Spacer()
            }

            SkeletonBar(height: 10)

            SkeletonBar(width: 160, height: 10)
        }
        .padding(14)
        .otaCard(Color.secondary, opacity: 0.06)
        .accessibilityLabel("Checking for updates")
    }
}
