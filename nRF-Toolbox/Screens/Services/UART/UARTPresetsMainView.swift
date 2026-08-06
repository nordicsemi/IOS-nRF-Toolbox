//
//  UARTPresetsMainView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 8/5/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - UARTPresetsMainView

struct UARTPresetsMainView: View {
    
    // MARK: EnvironmentObject
    
    @Environment(UARTViewModel.self) private var viewModel: UARTViewModel
    
    // MARK: Properties
    
    @State private var showNewPresetsAlert: Bool = false
    @State private var newPresetsName: String = ""
    @State private var showFileImporter = false
    
    // MARK: view
    
    var body: some View {
        @Bindable var bindableVM = viewModel
        DisclosureGroup {
            HStack {
                InlinePicker(title: "", systemImage: "command.square", selectedValue: $bindableVM.selectedPresets,
                             possibleValues: viewModel.presets)
                .labeledContentStyle(.accentedContent)
                
                Button {
                    viewModel.deleteSelectedPresets()
                } label: {
                    Image(systemName: "trash")
                        .frame(size: Constant.ButtonSize)
                }
                .disabled(viewModel.selectedPresets == .none)
                .buttonStyle(.bordered)
                .tint(Color.nordicRed)
                
                Button {
                    newPresetsName = ""
                    showNewPresetsAlert = true
                } label: {
                    Image(systemName: "plus")
                        .frame(size: Constant.ButtonSize)
                }
                .buttonStyle(.bordered)
                .tint(Color.universalAccentColor)
                
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(size: Constant.ButtonSize)
                }
                .buttonStyle(.bordered)
                .tint(Color.universalAccentColor)
            }
            
            UARTPresetControlView(viewModel.selectedPresets)
                .disabled(viewModel.selectedPresets == .none)
        } label: {
            Text("Presets")
                .font(.title2.bold())
        }
        .onChange(of: viewModel.selectedPresets) { oldValue, newValue in
            if (newValue != .none) {
                NordicAnalytics.logEvent(UARTChangeConfigurationEvent())
            }
            print("Changed from \(oldValue) to \(newValue)")
        }
        .tint(.universalAccentColor)
        .alert("New Presets", isPresented: $showNewPresetsAlert) {
            TextField("Type Name Here", text: $newPresetsName)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.newPresets(named: newPresetsName)
                    newPresetsName = ""
                    showNewPresetsAlert = false
                }
            
            Button("Cancel", role: .cancel) {
                showNewPresetsAlert = false
            }
            
            Button("Add") {
                viewModel.newPresets(named: newPresetsName)
                newPresetsName = ""
                showNewPresetsAlert = false
            }
        }
        .alert(viewModel.alertMessage, isPresented: $bindableVM.showAlert) {
            Button("OK", role: .cancel) { viewModel.showAlert = false }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { result in
            viewModel.importPresets(result: result)
        }
        .disabled(viewModel.isPlayInProgress)
    }
}

// MARK: Constant

extension Constant {
    
    // MARK: Size
    
    static let ButtonSize = CGSize(asSquare: 22.0)
}
