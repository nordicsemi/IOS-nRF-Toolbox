//
//  ConnectedDeviceView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 2/12/24.
//  Copyright © 2024 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import iOS_Bluetooth_Numbers_Database

// MARK: - SidebarDeviceView

struct SidebarDeviceView: View {
    
    // MARK: Environment
    
    @Environment(ConnectedDevicesViewModel.self) var connectedDevicesViewModel: ConnectedDevicesViewModel
    
    // MARK: Properties
    
    private let device: ConnectedDevicesViewModel.Device
    
    // MARK: Init
    
    init(_ device: ConnectedDevicesViewModel.Device) {
        self.device = device
    }
    
    // MARK: view
    
    var body: some View {
        VStack(alignment: .leading) {
            ScanResultItem(name: device.name ?? "Unnamed", services: device.services, isScanner: false)
            
            switch device.status {
            case .connected, .userInitiatedDisconnection, .connecting:
                EmptyView()
            case .error(let error):
                Label("Error: \(error.localizedDescription)", systemImage: "exclamationmark.circle")
                    .accentColor(.nordicRed)
                    .font(.caption)
            }
        }
    }
}

