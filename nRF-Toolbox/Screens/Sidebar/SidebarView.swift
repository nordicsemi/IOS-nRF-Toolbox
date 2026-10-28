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
    @Environment(NRFCloudViewModel.self) var cloud: NRFCloudViewModel
    
    @State private var showFirebasePermissionDialog = NordicAnalytics.needsPermission()
    @State private var showFirebaseSettingsDialog = false
    @State private var showCloudProjectSheet = false
    
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
            
            NRFCloudSection(showProjectSheet: $showCloudProjectSheet)
            
            Section {
                Button {
                    rootViewModel.showAboutView = true
                } label: {
                    Label("About nRF Toolbox", systemImage: "app.gift")
                }
                
                LinkView(
                    link: .github,
                    title: "Source Code (GitHub)",
                    systemImage: "keyboard",
                    url: "https://github.com/NordicSemiconductor/IOS-nRF-Toolbox"
                )
                
                LinkView(
                    link: .devZone,
                    title: "Help (Nordic DevZone)",
                    systemImage: "lifepreserver",
                    url: "https://devzone.nordicsemi.com/"
                )
                
                let isSelected = if case .logs = rootViewModel.selectedCategory {
                    true
                } else {
                    false
                }
                
                Button {
                    NordicAnalytics.logEvent(LinkOpenEvent(link: .logger))
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
        .alert("Sign in failed", isPresented: Binding(
            get: { cloud.account.errorMessage != nil },
            set: { if !$0 { cloud.account.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cloud.account.errorMessage ?? "")
        }
        .onChange(of: cloud.account.isSigningIn) { wasSigningIn, isSigningIn in
            if wasSigningIn, !isSigningIn, cloud.account.isSignedIn, cloud.selection == nil {
                showCloudProjectSheet = true
            }
        }
        .sheet(isPresented: $showCloudProjectSheet) {
            NavigationStack {
                NRFCloudProjectSheet()
            }
            .setupTranslucentBackground()
        }
        .sheet(isPresented: $showFirebasePermissionDialog) {
            NavigationStack {
                AnalyticsPermissionRequestDialog()
            }
            .setupTranslucentBackground()
        }
        .sheet(isPresented: $showFirebaseSettingsDialog) {
            NavigationStack {
                AnalyticsPermissionSwitchDialog()
            }
            .setupTranslucentBackground()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFirebaseSettingsDialog = true
                } label: {
                    Image("firebaseIcon")
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}
