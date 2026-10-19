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
    
    // MARK: Properties
    
    private let log = NordicLog(category: "DeviceScreen", subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: view

    var body: some View {
        @Bindable var deviceViewModel = deviceViewModel
        List {
            let hasServiceDiscoveryFailed = (deviceViewModel.errors.error as? ServiceError) == .serviceDiscoveryFailed
            
            if (deviceViewModel.showReconnectScreen) {
                DeviceDisconnectedView()
                
                
                switch deviceViewModel.device.status {
                case .error(let error):
                    if (error as? ConnectedDevicesViewModel.ConnectionError) != .connectionLost {
                        Section("Error") {
                            Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                                .foregroundStyle(Color.nordicRed)
                        }
                    }
                    
                    Section {
                        Button("Reconnect") {
                            reconnect()
                        }
                        .foregroundStyle(Color.universalAccentColor)
                        .centered()
                        .accessibilityIdentifier("reconnect_button")
                    }
                default:
                    Section {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .centered()
                            .tint(.nordicBlue)
                            .id(UUID()) // This fix issue with loader not being displayed when appears for the second time.
                    }
                }
            } else if (hasServiceDiscoveryFailed) {
                ServiceDiscoveryErrorView()
                
                Section {
                    Button("Disconnect") {
                        disconnect()
                    }
                    .foregroundStyle(Color.red)
                    .centered()
                    .accessibilityIdentifier("disconnect_button")
                }
            } else {
                deviceViewModel.supportedServiceViews()
                    .disabled(deviceViewModel.device.status.hashValue != Device.Status.connected.hashValue)
                    .disabled(!deviceViewModel.isInitialized)
                
                if let error = deviceViewModel.errors.warning {
                    Section("Warning") {
                        Text(error.errorDescription ?? "An unknown problem has occurred.")
                            .foregroundStyle(Color.nordicSun)
                    }
                }
                
                if let error = deviceViewModel.errors.error {
                    Section("Error") {
                        Text(error.errorDescription ?? "An unknown error has occurred.")
                            .foregroundStyle(Color.nordicRed)
                    }
                }
                
                Section("Device Information") {
                    NavigationStyledButton(title: "Open Inspector", systemImage: "info.circle") {
                        deviceViewModel.showDeviceSheet = true
                    }
                }
                
                if deviceViewModel.mayHaveStaleCache {
                    Section("Outdated attributes?") {
                        Text("The device reconnected with the same attributes as before. If you installed new firmware, iOS may be showing cached ones. Turn Bluetooth off and on in Settings (not Control Center), then reconnect.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(Color.universalAccentColor)
                    }
                }

                Section("Troubleshooting") {
                    DisclosureGroup {
                        Text("Turn off and on Bluetooth from Settings (not Control Center) to clear the cache.")
                            .foregroundStyle(Color.secondary)
                    } label: {
                        Label("Can't find your service?", systemImage: "exclamationmark.magnifyingglass")
                    }
                    .accentColor(.universalAccentColor)
                }
                
                Section("Connection") {
                    switch deviceViewModel.device.status {
                    case .userInitiatedDisconnection, .connecting:
                        Section {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .centered()
                                .tint(.nordicBlue)
                                .id(UUID()) // This fix issue with loader not being displayed when appears for the second time.
                        }
                    case .connected:
                        Button("Disconnect") {
                            disconnect()
                        }
                        .foregroundStyle(Color.red)
                        .centered()
                        .accessibilityIdentifier("disconnect_button")
                    case .error(let error):
                        Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.nordicRed)
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
    
    // MARK: reconnect()
    
    func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            Task { @MainActor in
                await connectedDevicesViewModel.reconnect(deviceViewModel.device)
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
