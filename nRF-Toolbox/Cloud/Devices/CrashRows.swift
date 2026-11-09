//
//  CrashRows.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct ReportRow: View {
    
    let title: String
    let date: Date?
    let release: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var subtitle: String {
        var parts: [String] = []
        if let date {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let release {
            parts.append("v\(release)")
        }
        return parts.joined(separator: " · ")
    }
}

struct CrashRow: View {
    
    let crash: NRFCloudCrash
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ReportRow(title: crash.title ?? crash.reason ?? "Crash",
                          date: crash.capturedDate, release: crash.release)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}
