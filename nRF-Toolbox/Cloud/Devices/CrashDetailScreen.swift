//
//  CrashDetailScreen.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

struct CrashDetailScreen: View {
    
    @Environment(NRFCloudViewModel.self) private var cloud
    @Environment(\.dismiss) private var dismiss
    
    let crash: NRFCloudCrash
    
    @State private var detail: NRFCloudCrashDetail?
    @State private var errorMessage: String?
    @State private var selectedThreadID: Int?
    
    var body: some View {
        List {
            if let detail {
                summary(detail)
                stackTrace(detail)
                registers(detail)
                logs(detail)
                coredump(detail)
            } else if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.nordicRed)
                    
                    Button("Retry") {
                        Task { await load() }
                    }
                    .foregroundStyle(Color.universalAccentColor)
                }
            } else {
                Section {
                    ProgressView()
                        .centered()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(crash.title ?? crash.reason ?? "Crash")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
            
            if let detail, let thread = selectedThread(in: detail) {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: report(detail, thread: thread))
                }
            }
        }
        .task {
            await load()
        }
    }
    
    private func summary(_ detail: NRFCloudCrashDetail) -> some View {
        Section("Summary") {
            row("Reason", detail.reason)
            row("Captured", detail.capturedDate?.formatted(date: .abbreviated, time: .standard))
            row("Software version", detail.release)
            row("Operating system", detail.operatingSystem)
            if let message = detail.message, !message.isEmpty {
                row("Message", message)
            }
        }
    }
    
    @ViewBuilder
    private func stackTrace(_ detail: NRFCloudCrashDetail) -> some View {
        if let thread = selectedThread(in: detail) {
            Section {
                if detail.threads.count > 1 {
                    Picker("Thread", selection: Binding(
                        get: { thread.id },
                        set: { selectedThreadID = $0 }
                    )) {
                        ForEach(detail.threads) { thread in
                            Text(threadLabel(thread)).tag(thread.id)
                        }
                    }
                }
                
                row("State", thread.state)
                if let size = thread.stackSize, let unused = thread.stackUnused {
                    row("Stack used", "\(size - unused) of \(size) bytes")
                }
                
                if thread.frames.isEmpty {
                    Text("No stack trace available for this thread")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(Array(thread.frames.enumerated()), id: \.offset) { offset, frame in
                    FrameRow(position: frame.index ?? offset, frame: frame)
                }
            } header: {
                Text("Stack Trace")
            }
        }
    }
    
    @ViewBuilder
    private func registers(_ detail: NRFCloudCrashDetail) -> some View {
        if !detail.faultRegisters.isEmpty {
            Section("Fault Registers") {
                ForEach(Array(detail.faultRegisters.enumerated()), id: \.offset) { _, register in
                    RegisterRow(register: register)
                }
                
                ForEach(detail.faultNotes, id: \.self) { note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        if let thread = selectedThread(in: detail), !thread.registers.isEmpty {
            Section {
                DisclosureGroup("\(thread.displayName) registers") {
                    ForEach(Array(thread.registers.enumerated()), id: \.offset) { _, register in
                        RegisterRow(register: register)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func logs(_ detail: NRFCloudCrashDetail) -> some View {
        if !detail.logs.isEmpty {
            Section {
                DisclosureGroup("Device log (\(detail.logs.count) lines)") {
                    ForEach(Array(detail.logs.enumerated()), id: \.offset) { _, line in
                        Text(line.text)
                            .font(.caption.monospaced())
                            .foregroundStyle(color(for: line.level))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func coredump(_ detail: NRFCloudCrashDetail) -> some View {
        if detail.coredumpStatus != nil || detail.buildID != nil {
            Section("Coredump") {
                row("Status", detail.coredumpStatus)
                if let buildID = detail.buildID {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Build ID")
                        
                        Text(buildID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func row(_ title: String, _ value: String?) -> some View {
        if let value {
            LabeledContent(title, value: value)
        }
    }
    
    private func selectedThread(in detail: NRFCloudCrashDetail) -> NRFCloudCrashDetail.Thread? {
        detail.threads.first(where: { $0.id == selectedThreadID }) ?? detail.defaultThread
    }
    
    private func threadLabel(_ thread: NRFCloudCrashDetail.Thread) -> String {
        var label = thread.displayName
        if thread.isCrashed {
            label += " (crashed)"
        } else if thread.isCurrent {
            label += " (current)"
        }
        return label
    }
    
    private func color(for level: String?) -> Color {
        switch level?.uppercased() {
        case "ERROR": Color.nordicRed
        case "WARNING": Color.nordicSun
        default: .secondary
        }
    }
    
    private func report(_ detail: NRFCloudCrashDetail, thread: NRFCloudCrashDetail.Thread) -> String {
        var lines = [detail.title ?? detail.reason ?? "Crash"]
        if let date = detail.capturedDate {
            lines.append("Captured: \(date.formatted(date: .abbreviated, time: .standard))")
        }
        if let release = detail.release {
            lines.append("Software version: \(release)")
        }
        lines.append("Thread: \(threadLabel(thread))")
        for (offset, frame) in thread.frames.enumerated() {
            let location = frame.location.map { " (\($0))" } ?? ""
            lines.append("#\(frame.index ?? offset) \(frame.function ?? "?")\(location) \(frame.address ?? "")")
        }
        return lines.joined(separator: "\n")
    }
    
    private func load() async {
        errorMessage = nil
        do {
            detail = try await cloud.crashDetail(for: crash)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FrameRow: View {
    
    let position: Int
    let frame: NRFCloudCrashDetail.Frame
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("#\(position)  \(frame.function ?? "unknown")")
                .font(.callout.monospaced())
            
            HStack {
                if let location = frame.location {
                    Text(location)
                }
                
                Spacer()
                
                if let address = frame.address {
                    Text(address)
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }
}

private struct RegisterRow: View {
    
    let register: NRFCloudCrashDetail.Register
    
    var body: some View {
        HStack {
            Text(register.name)
            
            Spacer()
            
            Text(register.value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.callout.monospaced())
    }
}
