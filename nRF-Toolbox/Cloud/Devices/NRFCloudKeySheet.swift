//
//  NRFCloudKeySheet.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct NRFCloudKeySheet: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    @Environment(\.dismiss) private var dismiss
    
    @State private var draft = NRFCloudCredentials(email: "", organization: "", project: "", apiKey: "")
    
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $draft.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                TextField("Organization slug", text: $draft.organization)
                TextField("Project slug", text: $draft.project)
                TextField("User API key", text: $draft.apiKey)
            } header: {
                Text("Memfault account")
            } footer: {
                Text("The slugs are in the project URL: app.memfault.com/organizations/<organization>/projects/<project>. The API key is a User API Key, stored in the Keychain on this device.")
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            
            if cloud.isConfigured {
                Section {
                    Button("Remove credentials", role: .destructive) {
                        cloud.removeCredentials()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("nRF Cloud")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let stored = cloud.credentials {
                draft = stored
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let credentials = draft
                    dismiss()
                    Task { await cloud.save(credentials) }
                }
                .disabled(!draft.isComplete)
            }
        }
    }
}
