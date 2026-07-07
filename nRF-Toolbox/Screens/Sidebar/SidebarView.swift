//
//  SidebarView.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 14/11/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import SwiftData

// MARK: - SidebarView

struct SidebarView: View {
    
    // MARK: Environment
    
    @Environment(RootNavigationViewModel.self) var rootViewModel: RootNavigationViewModel
    @Environment(ConnectedDevicesViewModel.self) var viewModel: ConnectedDevicesViewModel
    
    // MARK: view
    
    var body: some View {
        @Bindable var bindableVM = rootViewModel
        List(selection: $bindableVM.selectedCategory) {
            Section("Connected") {
                if viewModel.connectedDevices.isEmpty {
                    NoContentView(title: "No Connected Devices", systemImage: "cable.connector.slash", description: "Open the Scanner from below to connect to one or multiple Devices.")
                } else {
                    ForEach(Array(viewModel.connectedDevices.enumerated()), id: \.element.id) { index, device in
                        let isSelected = rootViewModel.selectedCategory == .device(device)
                        Button(action: {
                            rootViewModel.selectedCategory = RootNavigationView.MenuCategory.device(device)
                        }, label: {
                            SidebarDeviceView(device)
                                .setAccent(isSelected ? Color.white : .nordicBlue)
                                .tint(isSelected ? Color.white : .primarylabel)
                        })
                        .listRowBackground(isSelected ? Color.universalAccentColor : nil)
                        .accessibilityIdentifier("device_item_\(index)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if case .error = device.status {
                                Button(role: .destructive) {
                                    if isSelected {
                                        rootViewModel.selectedCategory = nil
                                    }
                                    viewModel.clearViewModel(device)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .accessibilityIdentifier("remove_device_\(index)")
                            }
                        }
                    }
                }
            }
            
            Section("Scanner") {
                let isSelected = rootViewModel.selectedCategory == .scanner
                Button(action: {
                    rootViewModel.selectedCategory = RootNavigationView.MenuCategory.scanner
                }, label: {
                    Label("Connect to Device", systemImage: "dot.radiowaves.right")
                        .setAccent(isSelected ? Color.white : .nordicBlue)
                        .tint(isSelected ? Color.white : .primarylabel)
                })
                .listRowBackground(isSelected ? Color.universalAccentColor : nil)
                .accessibilityIdentifier("scannerButton")
            }
            
            Section {
                Button {
                    rootViewModel.showAboutView = true
                } label: {
                    Label("About nRF Toolbox", systemImage: "app.gift")
                }
                
                SourceCodeLinkView(url: URL(string: "https://github.com/NordicSemiconductor/IOS-nRF-Toolbox")!)
                
                DevZoneLinkView()
                
                let isSelected = if case .logs = rootViewModel.selectedCategory {
                    true
                } else {
                    false
                }
                
                Button {
                    rootViewModel.selectedCategory = RootNavigationView.MenuCategory.logs(LogsTab.settings)
                } label: {
                    Label("Logs settings", systemImage: "gearshape")
                }
                .listRowBackground(isSelected ? Color.universalAccentColor : nil)
                .setAccent(isSelected ? Color.white : .nordicBlue)
                .tint(isSelected ? Color.white : .primarylabel)
            } header: {
                Text("More")
            } footer: {
                Text(Constant.copyright)
                    .foregroundStyle(Color.nordicMiddleGrey)
            }
            .setAccent(.universalAccentColor)
            .tint(.primarylabel)
        }
        .tint(Color.universalAccentColor)
        .listStyle(.insetGrouped)
    }
}
