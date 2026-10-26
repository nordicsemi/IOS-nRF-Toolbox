//
//  CrashesSection.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct CrashesSection: View {
    
    private static let displayLimit = 20
    
    @Environment(NRFCloudViewModel.self) private var cloud
    
    let identifiers: [String?]
    let isConnected: Bool
    
    @State private var cloudDevice: NRFCloudDevice?
    @State private var lookupFinished = false
    
    var body: some View {
        if cloud.isConfigured {
            Group {
                Section("nRF Cloud Crashes") {
                    crashes
                }
                
                Section("nRF Cloud Reboots") {
                    reboots
                }
            }
            .task(id: LoadTrigger(identifiers: identifiers.compactMap { $0 }, isConnected: isConnected)) {
                guard isConnected else { return }
                await load()
            }
        }
    }
    
    @ViewBuilder
    private var crashes: some View {
        if let cloudDevice {
            switch cloud.crashStates[cloudDevice.id] {
            case .none, .loading:
                ProgressView()
                    .centered()
            case .failed(let message):
                failure(message) {
                    await cloud.loadCrashes(for: cloudDevice)
                }
            case .loaded(let items) where items.isEmpty:
                Label("No crashes reported", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            case .loaded(let items):
                Label("\(items.count) crash\(items.count == 1 ? "" : "es") reported", systemImage: "exclamationmark.octagon")
                
                ForEach(items.prefix(Self.displayLimit)) { crash in
                    ReportRow(title: crash.title ?? crash.reason ?? "Crash",
                              date: crash.capturedDate, release: crash.release)
                }
                
                overflow(items.count)
            }
        } else {
            notRegistered
        }
    }
    
    @ViewBuilder
    private var reboots: some View {
        if let cloudDevice {
            switch cloud.rebootStates[cloudDevice.id] {
            case .none, .loading:
                ProgressView()
                    .centered()
            case .failed(let message):
                failure(message) {
                    await cloud.loadReboots(for: cloudDevice)
                }
            case .loaded(let items) where items.isEmpty:
                Label("No reboots reported", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            case .loaded(let items):
                Label("\(items.count) reboot\(items.count == 1 ? "" : "s") reported", systemImage: "arrow.clockwise")
                
                ForEach(items.prefix(Self.displayLimit)) { reboot in
                    ReportRow(title: reboot.reasonName, date: reboot.time, release: reboot.release)
                }
                
                overflow(items.count)
            }
        } else {
            notRegistered
        }
    }
    
    @ViewBuilder
    private var notRegistered: some View {
        if lookupFinished {
            Label("This device is not registered in the nRF Cloud project", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        } else {
            ProgressView()
                .centered()
        }
    }
    
    @ViewBuilder
    private func overflow(_ count: Int) -> some View {
        if count > Self.displayLimit {
            Text("and \(count - Self.displayLimit) older")
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func failure(_ message: String, retry: @escaping () async -> Void) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        
        Button("Retry") {
            Task { await retry() }
        }
    }
    
    private struct LoadTrigger: Hashable {
        let identifiers: [String]
        let isConnected: Bool
    }
    
    private func load() async {
        await cloud.refresh()
        cloudDevice = cloud.cloudDevice(matching: identifiers)
        lookupFinished = true
        if let cloudDevice {
            async let crashes: Void = cloud.loadCrashes(for: cloudDevice)
            async let reboots: Void = cloud.loadReboots(for: cloudDevice)
            _ = await (crashes, reboots)
        }
    }
}

private struct ReportRow: View {
    
    let title: String
    let date: Date?
    let release: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var subtitle: String {
        var parts: [String] = []
        if let date {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let release {
            parts.append("v\(release)")
        }
        return parts.joined(separator: " · ")
    }
}
