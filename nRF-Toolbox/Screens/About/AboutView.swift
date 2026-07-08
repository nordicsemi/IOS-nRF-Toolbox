//
//  AboutView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 11/3/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - AboutView

struct AboutView: View {
    
    // MARK: Environment
    
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: view
    
    var body: some View {
        List {
            Section("") {
                AppIconView()
                    .frame(width: 100, height: 100)
                    .cornerRadius(8.0)
                    .centered()
                    .padding(.top)
                    .iridescence()
                
                Text("nRF Toolbox")
                    .font(.title)
                    .centered()
                
                Text("Version \(Constant.appVersion(forBundleWithClass: DeviceDetailsViewModel.self))")
                    .foregroundStyle(.secondary)
                    .centered()
            }
            .listRowSeparator(.hidden)
            
            Section("Description") {
                Text("""
                nRF Toolbox is a multi-purpose container app providing access to multiple Bluetooh Low Energy profiles:
                
                • Quick Start
                • Monitoring & Diagnostic
                • Cycling Speed and Cadence
                • Running Speed and Cadence
                • Heart Rate Monitor
                • Blood Pressure Monitor
                • Health Thermometer Monitor
                • Glucose Monitor
                • Continuous Glucose Monitor
                • LED and Button Service
                • Battery Level
                • Throughput
                """)
            }
            .listRowSeparator(.hidden)
             
            Section("Requirements") {
                Label("Supported firmware flashed on device", systemImage: "cpu")
                
                Label("Device powered ON", systemImage: "bolt.fill")
                
                Label("Device in advertising range", systemImage: "wave.3.up")
            }
            .setAccent(.universalAccentColor)
            .tint(.primarylabel)
            .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.navigationStack)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
        }
    }
}
