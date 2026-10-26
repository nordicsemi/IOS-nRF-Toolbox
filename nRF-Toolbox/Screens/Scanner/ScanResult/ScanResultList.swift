//
//  ScanResultList.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 10/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - ScanResultList

struct ScanResultList: View {
    
    // MARK: Environment
    
    @Environment(ConnectedDevicesViewModel.self) private var viewModel: ConnectedDevicesViewModel
    @Environment(RootNavigationViewModel.self) private var rootViewModel: RootNavigationViewModel
    @Environment(NRFCloudViewModel.self) private var cloud: NRFCloudViewModel
    @Environment(\.dismiss) var dismiss

    private let log = NordicLog(category: "ScanResultList", subsystem: "com.nordicsemi.nrf-toolbox")

    // MARK: view

    var body: some View {
        let groups = cloud.group(viewModel.devices)
        let ordered = groups.inRange + groups.other
        List {
            if cloud.isConfigured {
                Section {
                    Label("\(groups.inRangeCloudCount) of \(cloud.devices.count) nRF Cloud devices in range",
                          systemImage: "cloud")
                    
                    if let errorMessage = cloud.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            
            if !groups.inRange.isEmpty {
                Section("nRF Cloud") {
                    ForEach(groups.inRange) { device in
                        deviceRow(device, index: ordered.firstIndex(where: { $0.id == device.id }) ?? 0)
                    }
                }
            }
            
            Section {
                ForEach(groups.other) { device in
                    deviceRow(device, index: ordered.firstIndex(where: { $0.id == device.id }) ?? 0)
                }
                
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        
                        Text("Scanning...")
                            .padding(.horizontal)
                    }
                    .padding(.top, 12)
                    
                    IndeterminateProgressView()
                        .accentColor(.universalAccentColor)
                }
            } header: {
                if cloud.isConfigured {
                    Text("Other Devices")
                }
            } footer: {
                Label("Tap a device to connect", systemImage: "hand.tap.fill")
            }
            
            if !groups.offline.isEmpty {
                Section("nRF Cloud · Offline") {
                    ForEach(groups.offline) { device in
                        Label {
                            VStack(alignment: .leading) {
                                Text(device.displayName)
                                
                                if device.displayName != device.id {
                                    Text(device.id)
                                        .font(.caption)
                                }
                            }
                        } icon: {
                            Image(systemName: "cloud")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func deviceRow(_ device: ConnectedDevicesViewModel.ScanResult, index: Int) -> some View {
        Button {
            Task {
                let result = await viewModel.connect(to: device)

                if case .success = result {
                    await navigateToConnectedDevice(id: device.id)
                } else {
                    dismiss() // Dismiss first before showing error.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.handleError(result: result)
                    }
                }
                
                viewModel.connectingDevice = nil
            }
        } label: {
            ScanResultItem(name: device.name, services: device.services,
                           showProgress: viewModel.connectingDevice == device)
        }.accessibilityIdentifier("scanner_item_\(index)")
    }

    private func navigateToConnectedDevice(id: UUID) async {
        for _ in 0..<50 {
            if let connectedDevice = viewModel.connectedDevices.first(where: { $0.id == id }),
               let deviceViewModel = viewModel.deviceViewModel(for: id),
               deviceViewModel.isInitialized || deviceViewModel.errors.error != nil {
                rootViewModel.selectedCategory = RootNavigationView.MenuCategory.device(connectedDevice)
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        log.error("Timed out waiting for service discovery to complete for id: \(id)")
    }
}
