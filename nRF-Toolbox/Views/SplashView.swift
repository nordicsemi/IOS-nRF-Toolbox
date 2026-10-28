//
//  SplashView.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 28/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct SplashView: View {
    
    private static let logoColor = Color(red: 0, green: 169.0 / 255, blue: 206.0 / 255)
    
    private static let margin: CGFloat = 16
    private static let canvasSize = CGSize(width: NordicLogoAnimation.viewport.width + 2 * margin,
                                           height: NordicLogoAnimation.viewport.height + 2 * margin)
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var startDate = Date()
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                Canvas { context, size in
                    draw(in: &context, size: size, at: elapsed)
                }
            }
            .aspectRatio(Self.canvasSize, contentMode: .fit)
            .frame(width: 260)
        }
        .onAppear {
            startDate = Date()
        }
        .accessibilityHidden(true)
    }
    
    private func draw(in context: inout GraphicsContext, size: CGSize, at time: TimeInterval) {
        let canvas = Self.canvasSize
        let scale = min(size.width / canvas.width, size.height / canvas.height)
        let textColor: Color = colorScheme == .dark ? .white : .black
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: Self.margin, y: Self.margin)
        for (index, shape) in NordicLogoAnimation.shapes.enumerated() {
            let opacity = shape.opacity(at: time)
            guard opacity > 0 else { continue }
            var layer = context
            if let name = shape.group, let group = NordicLogoAnimation.groups[name] {
                layer.concatenate(group.transform(at: time))
            }
            let color = shape.kind == .logo ? Self.logoColor : textColor
            layer.fill(NordicLogoPath.paths[index], with: .color(color.opacity(opacity)))
        }
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
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.5)) {
                isSplashShowing = false
            }
        }
    }
}
