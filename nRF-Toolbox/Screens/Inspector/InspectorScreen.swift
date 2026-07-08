//
//  InspectorScreen.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 30/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

// MARK: - InspectorScreen

struct InspectorScreen: View {
    
    // MARK: Environment
    
    @Environment(DeviceDetailsViewModel.self) private var deviceViewModel: DeviceDetailsViewModel
    @Environment(ConnectedDevicesViewModel.self) private var connectedDevicesViewModel: ConnectedDevicesViewModel
    
    // MARK: Private Properties
    
    @Environment(\.dismiss) var dismiss
    
    // MARK: Properties
    
    private let device: Device
        
    private var deviceIsConnected: Bool {
        switch device.status {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    // MARK: init
    
    init(_ device: Device) {
        self.device = device
    }
    
    // MARK: view
    
    var body: some View {
        List {
            Section("GATT") {
                NavigationLink {
                    AttributeTableScreen(deviceViewModel.attributeTable)
                } label: {
                    Label("Attribute Table", systemImage: "list.dash")
                        .setAccent(.nordicBlue)
                }
            }
            
            if let deviceVM = connectedDevicesViewModel.deviceViewModel(for: device.id) {
                if let signalViewModel = deviceVM.signalViewModel {
                    Section {
                        SignalChart()
                            .environment(signalViewModel.environment)
                    }
                    .disabled(!deviceIsConnected)
                }
                
                if let batteryServiceViewModel = deviceVM.batteryServiceViewModel {
                    Section {
                        BatteryView()
                            .environment(batteryServiceViewModel)
                    }
                    .disabled(!deviceIsConnected)
                }
                
                if let deviceInfo = deviceVM.deviceInfo {
                    Section("Device Info") {
                        DeviceInformationView(deviceInfo)
                    }
                }
            }
        }
        .navigationTitle("Device Inspector")
        .toolbarRole(.navigationStack)
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
}
