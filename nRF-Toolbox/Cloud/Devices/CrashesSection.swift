//
//  CrashesSection.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct CrashesSection: View {
    
    private static let displayLimit = 20
    
    @Environment(NRFCloudViewModel.self) private var cloud
    
    let viewModel: DeviceCrashesViewModel
    let onRefresh: () -> Void
    let onAddDevice: (() async -> Void)?
    
    private var cloudDevice: NRFCloudDevice? {
        viewModel.cloudDevice
    }
    
    var body: some View {
        if cloud.isConfigured {
            Group {
                Section {
                    if viewModel.isLoading {
                        IndeterminateProgressView()
                            .accentColor(.universalAccentColor)
                    }
                    
                    crashes
                } header: {
                    Text("nRF Cloud Crashes")
                }
                
                if DeviceCrashesViewModel.showsReboots {
                    Section("nRF Cloud Reboots") {
                        reboots
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var crashes: some View {
        if let cloudDevice {
            switch cloud.crashStates[cloudDevice.id] {
            case .none, .loading:
                Text("Downloading crashes…")
                    .foregroundStyle(.secondary)
            case .failed(let message):
                failure(message) {
                    onRefresh()
                }
            case .loaded(let items) where items.isEmpty:
                HStack {
                    Label("No crashes reported", systemImage: "checkmark.circle")
                        .setAccent(Color.universalAccentColor)
                    
                    Spacer()
                    
                    refreshButton
                }
            case .loaded(let items):
                HStack {
                    Label("\(items.count) crash\(items.count == 1 ? "" : "es") reported", systemImage: "exclamationmark.octagon")
                        .setAccent(Color.universalAccentColor)
                    
                    Spacer()
                    
                    refreshButton
                }
                
                if let latest = items.first {
                    CrashRow(crash: latest) {
                        viewModel.selectedCrash = latest
                    }
                }
                
                if items.count > 1 {
                    Button("See more") {
                        viewModel.showsAllCrashes = true
                    }
                    .foregroundStyle(Color.universalAccentColor)
                }
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
                    .setAccent(Color.universalAccentColor)
            case .loaded(let items):
                Label("\(items.count) reboot\(items.count == 1 ? "" : "s") reported", systemImage: "arrow.clockwise")
                    .setAccent(Color.universalAccentColor)
                
                ForEach(items.prefix(Self.displayLimit)) { reboot in
                    ReportRow(title: reboot.reasonName, date: reboot.time, release: reboot.release)
                }
                
                overflow(items.count)
            }
        } else {
            notRegistered
        }
    }
    
    private var refreshButton: some View {
        Button {
            onRefresh()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Refresh crashes")
    }
    
    @ViewBuilder
    private var notRegistered: some View {
        if viewModel.lookupFinished {
            HStack {
                Label("This device is not registered in the nRF Cloud project", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                refreshButton
            }
            
            if let onAddDevice {
                Button {
                    Task { await onAddDevice() }
                } label: {
                    HStack {
                        Label("Add to Project", systemImage: "plus.circle")
                        
                        if viewModel.isAddingDevice {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .foregroundStyle(Color.universalAccentColor)
                .disabled(viewModel.isAddingDevice)
            }
            
            if let error = viewModel.addDeviceError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.nordicRed)
            }
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
            .foregroundStyle(Color.nordicRed)
        
        Button("Retry") {
            Task { await retry() }
        }
        .foregroundStyle(Color.universalAccentColor)
    }
}
