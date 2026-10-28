//
//  SidebarCloudSections.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 28/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct MyNordicSection: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    
    var body: some View {
        Section("myNordic") {
            if let userName = cloud.account.userName {
                signedIn(userName)
            } else {
                signedOut
            }
        }
    }
    
    private func signedIn(_ userName: String) -> some View {
        HStack(spacing: 14) {
            Text(initials(of: userName))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [.accentColor, .accentColor.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(userName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Signed in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    cloud.signOut()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Not signed in")
                        .font(.headline)
                    Text("Sign in to see crashes and reboots of your devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                Task { await cloud.signIn() }
            } label: {
                HStack(spacing: 8) {
                    if cloud.account.isSigningIn {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(cloud.account.isSigningIn ? "Signing in…" : "Sign in to myNordic")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(cloud.account.isSigningIn)
        }
        .padding(.vertical, 4)
    }
    
    private func initials(of name: String) -> String {
        let letters = name.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." })
            .prefix(2)
            .compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

struct NRFCloudSection: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    
    @Binding var showProjectSheet: Bool
    
    private var isSignedIn: Bool {
        cloud.account.isSignedIn
    }
    
    var body: some View {
        Section("nRF Cloud") {
            Button {
                showProjectSheet = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(isSignedIn ? Color.accentColor : Color.secondary.opacity(0.5),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(cloud.selection == nil ? .secondary : .primary)
                            .lineLimit(1)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if cloud.isLoading {
                        ProgressView()
                    } else if isSignedIn {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isSignedIn)
        }
    }
    
    private var title: String {
        cloud.selection?.project ?? "Select project"
    }
    
    private var subtitle: String {
        guard isSignedIn else { return "Sign in to choose a project" }
        guard let selection = cloud.selection else { return "Tap to choose a project" }
        guard !cloud.devices.isEmpty else { return selection.organization }
        let count = cloud.devices.count
        return "\(selection.organization) · \(count) \(count == 1 ? "device" : "devices")"
    }
}
