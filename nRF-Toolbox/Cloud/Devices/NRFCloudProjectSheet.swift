//
//  NRFCloudProjectSheet.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct NRFCloudProjectSheet: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    @Environment(\.dismiss) private var dismiss
    
    @State private var organization = ""
    @State private var project = ""
    
    private var organizationName: String? {
        cloud.organizations.first { $0.slug == organization }?.name
    }
    
    var body: some View {
        List {
            header
            organizationSection
            projectsSection
            errorSection
        }
        .listStyle(.insetGrouped)
        .sensoryFeedback(.selection, trigger: project)
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
            guard !newValue.isEmpty else { return }
            if newValue != cloud.selection?.organization {
                project = ""
            }
            guard newValue != cloud.selection?.organization || cloud.projects.isEmpty else { return }
            Task { await cloud.loadProjects(organization: newValue) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.universalAccentColor)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    cloud.selectProject(organization: organization, project: project)
                    dismiss()
                }
                .foregroundStyle(Color.universalAccentColor)
                .disabled(organization.isEmpty || project.isEmpty)
            }
        }
    }
    
    private var header: some View {
        Section {
            Text("Crashes and reboots of your devices are loaded from the selected nRF Cloud project.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var organizationSection: some View {
        Section("Organization") {
            Menu {
                Picker("Organization", selection: $organization) {
                    ForEach(cloud.organizations) { item in
                        Text(item.name).tag(item.slug)
                    }
                }
            } label: {
                HStack {
                    Label {
                        Text(organizationName ?? (cloud.isLoadingProjects ? "Loading…" : "No organization"))
                            .foregroundStyle(organizationName == nil ? .secondary : .primary)
                    } icon: {
                        Image(systemName: "building.2")
                            .setAccent(Color.universalAccentColor)
                    }
                    
                    Spacer()
                    
                    if cloud.organizations.count > 1 {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(cloud.organizations.count < 2)
        }
    }
    
    private var projectsSection: some View {
        Section("Projects") {
            if cloud.isLoadingProjects && cloud.projects.isEmpty {
                ProgressView()
                    .centered()
            } else if cloud.projects.isEmpty && cloud.projectsErrorMessage == nil {
                Label("No projects in this organization", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cloud.projects) { item in
                    projectRow(item)
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let message = cloud.projectsErrorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.nordicRed)
                
                Button("Try Again") {
                    Task { await cloud.loadOrganizations() }
                }
                .foregroundStyle(Color.universalAccentColor)
            }
        }
    }
    
    private func projectRow(_ item: NRFCloudProject) -> some View {
        let isSelected = item.slug == project
        return Button {
            project = item.slug
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .foregroundStyle(.primary)
                        Text(item.slug)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "folder")
                        .setAccent(Color.universalAccentColor)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.universalAccentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
