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
        .animation(.default, value: cloud.projects)
        .animation(.default, value: cloud.isLoadingProjects)
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
    
    private var header: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        LinearGradient(colors: [.accentColor, .accentColor.opacity(0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: .accentColor.opacity(0.35), radius: 12, y: 6)
                
                Text("Choose a project")
                    .font(.title2.bold())
                
                Text("Crashes and reboots of your devices are loaded from the selected nRF Cloud project.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
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
                HStack(spacing: 12) {
                    iconBadge("building.2.fill")
                    
                    Text(organizationName ?? (cloud.isLoadingProjects ? "Loading…" : "No organization"))
                        .foregroundStyle(organizationName == nil ? .secondary : .primary)
                    
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
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading projects…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
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
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                
                Button {
                    Task { await cloud.loadOrganizations() }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
            }
        }
    }
    
    private func projectRow(_ item: NRFCloudProject) -> some View {
        let isSelected = item.slug == project
        return Button {
            project = item.slug
        } label: {
            HStack(spacing: 12) {
                iconBadge("folder.fill", isHighlighted: isSelected)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Text(item.slug)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .symbolEffect(.bounce, value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func iconBadge(_ systemName: String, isHighlighted: Bool = true) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(isHighlighted ? Color.accentColor : Color.secondary.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
