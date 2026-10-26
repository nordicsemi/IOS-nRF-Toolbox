//
//  DeviceScreen.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 25/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - DeviceScreen

struct DeviceScreen: View {

    // MARK: Environment
    
    @Environment(\.dismiss) var dismiss
    
    @Environment(DeviceDetailsViewModel.self) private var deviceViewModel: DeviceDetailsViewModel
    @Environment(RootNavigationViewModel.self) var navigationViewModel: RootNavigationViewModel
    @Environment(ConnectedDevicesViewModel.self) private var connectedDevicesViewModel: ConnectedDevicesViewModel
    @Environment(NRFCloudViewModel.self) private var cloudViewModel: NRFCloudViewModel
    
    // MARK: Properties
    
    @State private var crashes = DeviceCrashesViewModel()
    
    private let log = NordicLog(category: "DeviceScreen", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: view

    var body: some View {
        @Bindable var deviceViewModel = deviceViewModel
        @Bindable var crashes = crashes
        List {
            switch deviceViewModel.screenState {
            case .disconnected:
                DeviceDisconnectedView()
                    .logAppearance("DeviceDisconnectedView", log)

                switch deviceViewModel.device.status {
                case .error(let error):
                    if (error as? ConnectedDevicesViewModel.ConnectionError) != .connectionLost {
                        Section("Error") {
                            Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                                .foregroundStyle(Color.nordicRed)
                                .logAppearance("Disconnected error label", log)
                        }
                    }
                    
                    Section {
                        Button("Reconnect") {
                            reconnect()
                        }
                        .foregroundStyle(Color.universalAccentColor)
                        .centered()
                        .accessibilityIdentifier("reconnect_button")
                        .logAppearance("Reconnect button", log)
                    }
                default:
                    progressSection("Disconnected progress")
                }
            case .discovering:
                ServiceDiscoveryProgressView()
                    .logAppearance("ServiceDiscoveryProgressView", log)
            case .discoveryFailed:
                ServiceDiscoveryErrorView()
                    .logAppearance("ServiceDiscoveryErrorView", log)
                
                Section {
                    Button("Disconnect") {
                        disconnect()
                    }
                    .foregroundStyle(Color.red)
                    .centered()
                    .accessibilityIdentifier("disconnect_button")
                    .logAppearance("Disconnect button (discovery failed)", log)
                }
            case .ready:
                deviceViewModel.supportedServiceViews(afterObservability: crashesSection)
                    .disabled(deviceViewModel.device.status.hashValue != Device.Status.connected.hashValue)
                    .disabled(!deviceViewModel.isInitialized)
                    .logAppearance("Supported service views", log)
                
                if let error = deviceViewModel.errors.warning {
                    Section("Warning") {
                        Text(error.errorDescription ?? "An unknown problem has occurred.")
                            .foregroundStyle(Color.nordicSun)
                            .logAppearance("Warning", log)
                    }
                }
                
                if let error = deviceViewModel.errors.error {
                    Section("Error") {
                        Text(error.errorDescription ?? "An unknown error has occurred.")
                            .foregroundStyle(Color.nordicRed)
                            .logAppearance("Error", log)
                    }
                }
                
                Section("Device Information") {
                    NavigationStyledButton(title: "Open Inspector", systemImage: "info.circle") {
                        deviceViewModel.showDeviceSheet = true
                    }
                    .logAppearance("Open Inspector button", log)
                }
                
                Section("Troubleshooting") {
                    DisclosureGroup {
                        Text("Turn off and on Bluetooth from Settings (not Control Center) to clear the cache.")
                            .foregroundStyle(Color.secondary)
                    } label: {
                        Label("Can't find your service?", systemImage: "exclamationmark.magnifyingglass")
                    }
                    .accentColor(.universalAccentColor)
                    .logAppearance("Troubleshooting", log)
                }
                
                Section("Connection") {
                    switch deviceViewModel.device.status {
                    case .userInitiatedDisconnection, .connecting:
                        connectionProgress
                    case .connected where !deviceViewModel.isInitialized:
                        connectionProgress
                    case .connected:
                        Button("Disconnect") {
                            disconnect()
                        }
                        .foregroundStyle(Color.red)
                        .centered()
                        .accessibilityIdentifier("disconnect_button")
                        .logAppearance("Disconnect button", log)
                    case .error(let error):
                        Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.nordicRed)
                            .logAppearance("Connection error label", log)
                    }
                }
            }
        }
        .task {
            log.debug("DeviceScreen.task()")
            connectedDevicesViewModel.selectedDevice = deviceViewModel.device
        }
        .onDisappear {
            log.debug("DeviceScreen.onDisappear()")
        }
        .listStyle(.insetGrouped)
        .navigationTitle(deviceViewModel.device.name ?? "Unnamed")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: crashLoadTrigger) {
            guard crashLoadTrigger.isConnected else { return }
            crashes.request(identifiers: crashIdentifiers, cloud: cloudViewModel, reason: "device connected")
        }
        .onChange(of: deviceViewModel.observabilityViewModel?.largeUploadsCompleted) { _, completed in
            guard let completed, completed > 0 else { return }
            log.info("Large Observability upload completed. Reloading crashes.")
            crashes.request(identifiers: crashIdentifiers, cloud: cloudViewModel, reason: "large upload completed")
        }
        .sheet(item: $crashes.selectedCrash) { crash in
            NavigationStack {
                CrashDetailScreen(crash: crash)
            }
            .setupTranslucentBackground()
        }
        .sheet(isPresented: $deviceViewModel.showDeviceSheet) {
            NavigationStack {
                InspectorScreen(deviceViewModel.device)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .setupTranslucentBackground()
        }
        .onChange(of: connectedDevicesViewModel.connectedDevices) {
            guard connectedDevicesViewModel.connectedDevices.firstIndex(where: \.id, equals: deviceViewModel.device.id) == nil else { return }
            log.debug("Device \(deviceViewModel.device) not found in Connected Devices anymore. Dismissing.")
            dismiss()
        }
        .toolbar { LogsToolbarItem() }
    }
    
    // MARK: crashesSection
    
    private var crashesSection: some View {
        CrashesSection(viewModel: crashes) {
            crashes.request(identifiers: crashIdentifiers, cloud: cloudViewModel, reason: "manual refresh")
        }
    }
    
    private var crashIdentifiers: [String?] {
        [deviceViewModel.deviceInfo?.serialNumber, deviceViewModel.device.name]
    }
    
    private var crashLoadTrigger: CrashLoadTrigger {
        CrashLoadTrigger(identifiers: crashIdentifiers.compactMap { $0 },
                         isConnected: deviceViewModel.device.status.hashValue == Device.Status.connected.hashValue
                             && deviceViewModel.isInitialized)
    }
    
    // MARK: connectionProgress

    private var connectionProgress: some View {
        Section {
            ProgressView()
                .progressViewStyle(.circular)
                .centered()
                .tint(.nordicBlue)
                .id(UUID()) // This fix issue with loader not being displayed when appears for the second time.
                .logAppearance("Connection progress", log)
        }
    }

    // MARK: progressSection
    
    private func progressSection(_ name: String) -> some View {
        Section {
            ProgressView()
                .progressViewStyle(.circular)
                .centered()
                .tint(.nordicBlue)
                .id(UUID()) // This fix issue with loader not being displayed when appears for the second time.
                .logAppearance(name, log)
        }
    }
    
    // MARK: reconnect()
    
    func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            Task { @MainActor in
                await connectedDevicesViewModel.reconnect(deviceViewModel.device, userInitiated: true)
            }
        }
    }
    
    // MARK: disconnect()
    
    func disconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            Task { @MainActor in
                try await connectedDevicesViewModel.disconnectAndRemoveViewModel(deviceViewModel.device)
                dismiss()
            }
        }
    }
}

// MARK: - CrashLoadTrigger

private struct CrashLoadTrigger: Hashable {
    
    let identifiers: [String]
    let isConnected: Bool
}

// MARK: - logAppearance

private extension View {

    func logAppearance(_ name: String, _ log: NordicLog) -> some View {
        onAppear {
            log.debug("\(name) displayed.")
        }
    }
}
