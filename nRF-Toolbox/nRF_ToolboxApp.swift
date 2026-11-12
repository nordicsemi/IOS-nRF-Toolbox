//
//  nRF_ToolboxApp.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 07/07/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftData
import SwiftUI
import iOS_BLE_Library_Mock

// MARK: - App

@main
struct nRF_ToolboxApp: App {
    
    @UIApplicationDelegateAdaptor(AnalyticsAppDelegate.self) var delegate
    
    private static let centralDelegate = RestoringCentralManagerDelegate()
    private static let centralManager = CentralManager(
        centralManagerDelegate: centralDelegate,
        options: [CBCentralManagerOptionRestoreIdentifierKey: RestoringCentralManagerDelegate.restoreIdentifier]
    )
    
    @State var viewModel = AppViewModel()
    @State var accountViewModel: NordicAccountViewModel
    @State var cloudViewModel: NRFCloudViewModel
    @State var connectedDevicesViewModel: ConnectedDevicesViewModel = ConnectedDevicesViewModel(centralManager: centralManager, restoredPeripherals: centralDelegate.restoredPeripheralsSubject)
    
    init() {
        let identity = NordicIdentityRepository()
        _accountViewModel = State(initialValue: NordicAccountViewModel(identity: identity))
        _cloudViewModel = State(initialValue: NRFCloudViewModel(identity: identity))
        BluetoothEmulation.shared.simulateState()
        BluetoothEmulation.shared.simulatePeripherals()
    }
    
    // MARK: view
    
    var body: some Scene {
        WindowGroup {
            SplashContainer(preload: {
                await accountViewModel.signIn()
                await cloudViewModel.start()
            }) {
                RootNavigationView()
                    .setupTranslucentBackground()
                    .environment(viewModel)
                    .environment(accountViewModel)
                    .environment(cloudViewModel)
                    .environment(connectedDevicesViewModel)
            }
        }
    }
}
