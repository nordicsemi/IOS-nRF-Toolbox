//
//  SidebarCloudSections.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 28/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct NRFCloudSection: View {
    
    @Environment(NordicAccountViewModel.self) private var account
    @Environment(NRFCloudViewModel.self) private var cloud
    
    @Binding var showProjectSheet: Bool
    
    var body: some View {
        Section("nRF Cloud") {
            if let userName = account.userName {
                signedIn(userName)
                projectRow
            } else {
                signedOut
            }
        }
    }
    
    private func signedIn(_ userName: String) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .lineLimit(1)
                    
                    Text("Signed in to myNordic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "person.crop.circle")
                    .setAccent(Color.universalAccentColor)
            }
            
            Spacer()
            
            Menu {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    account.signOut()
                    cloud.didSignOut()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.universalAccentColor)
            }
        }
    }
    
    private var signedOut: some View {
        Button {
            Task {
                await account.signIn()
                await cloud.didSignIn()
            }
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.isSigningIn ? "Signing in…" : "Sign in to myNordic")
                        
                        Text("Pick an nRF Cloud project and see crashes and reboots of your devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle")
                        .setAccent(Color.universalAccentColor)
                }
                
                if account.isSigningIn {
                    Spacer()
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(account.isSigningIn)
    }
    
    private var projectRow: some View {
        NavigationStyledButton(title: title, systemImage: "cloud") {
            showProjectSheet = true
        }
        .overlay(alignment: .trailing) {
            if cloud.isLoading {
                ProgressView()
                    .padding(.trailing, 24)
            }
        }
    }
    
    private var title: String {
        cloud.selection?.project ?? "Select project"
    }
}
