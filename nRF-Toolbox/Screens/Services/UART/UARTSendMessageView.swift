//
//  UARTSendMessageView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 6/5/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct UARTSendMessageView: View {
    
    // MARK: EnvironmentObject
    
    @Environment(UARTViewModel.self) private var viewModel: UARTViewModel
    @FocusState private var isFocused: Bool
    
    // MARK: view
    
    var body: some View {
        HStack {
            ZStack(alignment: .leading) {
                
                BlinkingCursorView().hidden(!viewModel.newMessage.isEmpty)

                @Bindable var bindableVM = viewModel
                HStack(spacing: 0) {
                    TextField("UART Message", text: $bindableVM.newMessage, prompt: Text("Write new message here")).focused($isFocused).tint(.clear)
                    BlinkingCursorView().padding(.leading, 6).hidden()
                }
                
                HStack(spacing: 0) {
                    Text(viewModel.newMessage).lineLimit(1).hidden()
                    BlinkingCursorView().padding(.leading, 2).hidden(viewModel.newMessage.isEmpty)
                }
            }

            Button {
                viewModel.sendMessage()
            } label: {
                Label("Send", systemImage: "paperplane.fill")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(Color.universalAccentColor)
        }
        .onAppear {
            self.isFocused = true
        }
    }
}
