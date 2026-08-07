//
//  UARTEditPresetsView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 15/5/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import AEXML

// MARK: - UARTEditPresetsView

struct UARTEditPresetsView: View {
    
    // MARK: EnvironmentObject
    
    @Environment(UARTViewModel.self) private var viewModel: UARTViewModel
    
    // MARK: Private Properties
  
    @State private var name: String = ""
    @State private var sequence: [UARTSequenceItem] = [UARTSequenceItem]()
    
    private let appLog = NordicLog(category: #file)
    
    // MARK: view
    
    var body: some View {
        List {
            Section("Name") {
                CancellableTextField("Type preset's set name here", cancelText: name, icon: .text, text: $name)
                    .keyboardType(.alphabet)
                    .submitLabel(.done)
                    .onSubmit {
                        viewModel.updateSelectedPresetsName(name)
                    }
            }
            
            Section("Presets") {
                UARTPresetsGridView(presets: viewModel.editedPresets, onTap: { i in
                    viewModel.editCommandIndex = i
                    viewModel.showEditPresetSheet = true
                }, onLongPress: { i in
                    guard viewModel.editedPresets.commands[i].data != nil else { return }
                    sequence.append(.command(viewModel.editedPresets.commands[i]))
                })
                .aspectRatio(1, contentMode: .fit)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section("Command Sequence") {
                Text ("Tip: Long press command to add it to a sequence.")
                    .foregroundColor(.secondary)
                    .font(Font.caption.bold())
                ForEach(sequence.indices, id: \.self) { index in
                    SequenceItemView(item: $sequence[index])
                }
                Button("Add Delay") {
                    sequence.append(.delay(1))
                }
                .tint(.universalAccentColor)
                .centered()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit \(viewModel.selectedPresets.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.showEditPresetsSheet = false
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewModel.updateSelectedPresetsName(name)
                    viewModel.updateSelectedPresetsSequence(sequence)
                    viewModel.savePresets()
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
        .doOnce {
            viewModel.startEdit()
            name = viewModel.editedPresets.name
            sequence = viewModel.editedPresets.sequence
        }
    }
}
