//
//  NRFCloudProjectSheet.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct NRFCloudProjectSheet: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    @Environment(\.dismiss) private var dismiss
    
    @State private var organization = ""
    @State private var project = ""
    
    var body: some View {
        Form {
            Section("Organization") {
                Picker("Organization", selection: $organization) {
                    ForEach(cloud.organizations) { item in
                        Text(item.name).tag(item.slug)
                    }
                }
            }
            
            Section("Project") {
                Picker("Project", selection: $project) {
                    ForEach(cloud.projects) { item in
                        Text(item.name).tag(item.slug)
                    }
                }
            }
            
            if let message = cloud.projectsErrorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await cloud.loadOrganizations() }
                    }
                }
            }
        }
        .overlay {
            if cloud.isLoadingProjects && cloud.projects.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading projects…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("nRF Cloud")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            organization = cloud.selection?.organization ?? ""
            project = cloud.selection?.project ?? ""
            if cloud.organizations.isEmpty {
                await cloud.loadOrganizations()
            }
            if organization.isEmpty {
                organization = cloud.organizations.first?.slug ?? ""
            }
        }
        .onChange(of: cloud.organizations) { _, organizations in
            if organization.isEmpty {
                organization = organizations.first?.slug ?? ""
            }
        }
        .onChange(of: cloud.selection) { _, selection in
            if selection != nil { dismiss() }
        }
        .onChange(of: organization) { _, newValue in
            guard !newValue.isEmpty, newValue != cloud.selection?.organization || cloud.projects.isEmpty else { return }
            project = ""
            Task { await cloud.loadProjects(organization: newValue) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    cloud.selectProject(organization: organization, project: project)
                    dismiss()
                }
                .disabled(organization.isEmpty || project.isEmpty)
            }
        }
    }
}
