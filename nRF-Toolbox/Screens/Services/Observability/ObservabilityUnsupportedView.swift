//
//  ObservabilityUnsupportedView.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - ObservabilityUnsupportedView

struct ObservabilityUnsupportedView: View {

    // MARK: Private

    private static let appStoreURL = URL(string: "https://apps.apple.com/us/app/nrf-connect-device-manager/id1519423539")!

    // MARK: view

    var body: some View {
        VStack(spacing: 16) {
            Image("device_manager")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(.nordicBlue)
                .frame(width: 56, height: 56)

            Text("MDS is not supported")

            Text("MDS service is not available in the current version of the app. Please use the nRF Connect Device Manager app from Nordic Semiconductor to update your device's firmware.")
                .font(.caption)

            Link(destination: Self.appStoreURL) {
                AppStoreBadge()
            }
        }
    }
}

// MARK: - AppStoreBadge

/// A native recreation of Apple's "Download on the App Store" badge, built entirely
/// from system components (SF Symbols + system fonts) rather than bundling Apple's
/// trademarked marketing artwork.
private struct AppStoreBadge: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 24, weight: .regular))

            VStack(alignment: .leading, spacing: 0) {
                Text("Download on the")
                    .font(.system(size: 10, weight: .regular))
                Text("App Store")
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
