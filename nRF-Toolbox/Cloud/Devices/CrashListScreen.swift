//
//  CrashListScreen.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct CrashListScreen: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    
    let viewModel: DeviceCrashesViewModel
    
    private var crashes: [NRFCloudCrash] {
        guard let device = viewModel.cloudDevice,
              case .loaded(let items) = cloud.crashStates[device.id] else { return [] }
        return items
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                IndeterminateProgressView()
                    .accentColor(.universalAccentColor)
            }
            
            ForEach(crashes) { crash in
                CrashRow(crash: crash) {
                    viewModel.selectedCrash = crash
                }
            }
        }
        .navigationTitle("Crashes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
