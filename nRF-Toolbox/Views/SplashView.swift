//
//  SplashView.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 28/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct SplashView: View {
    
    @State private var isLogoVisible = false
    @State private var isGlowVisible = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            Circle()
                .fill(RadialGradient(colors: [Color.accentColor.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 180))
                .frame(width: 360, height: 360)
                .scaleEffect(isGlowVisible ? 1.15 : 0.3)
                .opacity(isGlowVisible ? 1 : 0)
            
            Image("NordicLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .scaleEffect(isLogoVisible ? 1 : 0.6)
                .opacity(isLogoVisible ? 1 : 0)
                .blur(radius: isLogoVisible ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
                isLogoVisible = true
            }
            withAnimation(.easeOut(duration: 1.4)) {
                isGlowVisible = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct SplashContainer<Content: View>: View {
    
    @State private var isSplashShowing = true
    
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            content()
            
            if isSplashShowing {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.5)) {
                isSplashShowing = false
            }
        }
    }
}
