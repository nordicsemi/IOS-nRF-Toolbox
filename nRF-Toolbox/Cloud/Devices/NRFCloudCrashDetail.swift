//
//  NRFCloudCrashDetail.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudCrashDetail: Decodable, Equatable {
    
    struct Frame: Equatable {
        let index: Int?
        let function: String?
        let file: String?
        let line: Int?
        let address: String?
        let type: String?
        
        var location: String? {
            guard let file else { return nil }
            let name = file.split(separator: "/").last.map(String.init) ?? file
            return line.map { "\(name):\($0)" } ?? name
        }
    }
    
    struct Register: Equatable {
        let name: String
        let value: String
    }
    
    struct Thread: Equatable, Identifiable {
        let id: Int
        let name: String?
        let state: String?
        let isCrashed: Bool
        let isCurrent: Bool
        let stackSize: Int?
        let stackUnused: Int?
        let frames: [Frame]
        let registers: [Register]
        
        var displayName: String {
            name ?? "Thread \(id)"
        }
    }
    
    struct LogLine: Equatable {
        let text: String
        let level: String?
    }
    
    let id: Int
    let title: String?
    let reason: String?
    let message: String?
    let capturedDate: Date?
    let release: String?
    let issueID: Int?
    let operatingSystem: String?
    let threads: [Thread]
    let faultRegisters: [Register]
    let faultNotes: [String]
    let logs: [LogLine]
    let coredumpStatus: String?
    let buildID: String?
    
    var defaultThread: Thread? {
        threads.first(where: \.isCrashed) ?? threads.first(where: \.isCurrent) ?? threads.first
    }
    
    static func decode(from data: Data) throws -> NRFCloudCrashDetail {
        struct Envelope: Decodable {
            let data: NRFCloudCrashDetail
        }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return envelope.data
        }
        return try JSONDecoder().decode(NRFCloudCrashDetail.self, from: data)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, reason, message, entries, coredump
        case capturedDate = "captured_date"
        case softwareVersion = "software_version"
        case issueID = "issue_id"
    }
    
    private enum VersionKeys: String, CodingKey {
        case version
    }
    
    private enum EntriesKeys: String, CodingKey {
        case threads, faults, logs
        case operatingSystem = "operating_system"
    }
    
    private enum FaultsKeys: String, CodingKey {
        case registers, notes
    }
    
    private enum LogsKeys: String, CodingKey {
        case memfaultSDK = "memfault_sdk"
    }
    
    private enum LogBufferKeys: String, CodingKey {
        case lines
    }
    
    private enum CoredumpKeys: String, CodingKey {
        case status
        case buildID = "build_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try? container.decode(String.self, forKey: .title)
        reason = try? container.decode(String.self, forKey: .reason)
        message = try? container.decode(String.self, forKey: .message)
        capturedDate = (try? container.decode(String.self, forKey: .capturedDate)).flatMap(Date.init(memfault:))
        issueID = try? container.decode(Int.self, forKey: .issueID)
        release = (try? container.nestedContainer(keyedBy: VersionKeys.self, forKey: .softwareVersion))
            .flatMap { try? $0.decode(String.self, forKey: .version) }
        
        let entries = try? container.nestedContainer(keyedBy: EntriesKeys.self, forKey: .entries)
        operatingSystem = entries.flatMap { try? $0.decode(String.self, forKey: .operatingSystem) }
        threads = (entries.flatMap { try? $0.decode([ThreadPayload].self, forKey: .threads) } ?? []).map(\.thread)
        
        let faults = try? entries?.nestedContainer(keyedBy: FaultsKeys.self, forKey: .faults)
        faultRegisters = (faults.flatMap { try? $0.decode([RegisterPayload].self, forKey: .registers) } ?? []).map(\.register)
        faultNotes = faults.flatMap { try? $0.decode([String].self, forKey: .notes) } ?? []
        
        let logs = try? entries?.nestedContainer(keyedBy: LogsKeys.self, forKey: .logs)
        let buffer = try? logs?.nestedContainer(keyedBy: LogBufferKeys.self, forKey: .memfaultSDK)
        self.logs = (buffer.flatMap { try? $0.decode([LogPayload].self, forKey: .lines) } ?? []).map(\.logLine)
        
        let coredump = try? container.nestedContainer(keyedBy: CoredumpKeys.self, forKey: .coredump)
        coredumpStatus = coredump.flatMap { try? $0.decode(String.self, forKey: .status) }
        buildID = coredump.flatMap { try? $0.decode(String.self, forKey: .buildID) }
    }
}

private struct FlexibleValue: Decodable {
    
    let text: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            text = string
        } else if let number = try? container.decode(Int.self) {
            text = "0x" + String(number, radix: 16, uppercase: true)
        } else {
            text = nil
        }
    }
}

private struct RegisterPayload: Decodable {
    
    let name: String?
    let data: FlexibleValue?
    let value: FlexibleValue?
    
    var register: NRFCloudCrashDetail.Register {
        NRFCloudCrashDetail.Register(name: name ?? "?", value: formattedValue ?? data?.text ?? "-")
    }
    
    private var formattedValue: String? {
        guard let raw = value?.text else { return nil }
        let number = raw.hasPrefix("0x") ? Int(raw.dropFirst(2), radix: 16) : Int(raw)
        return number.map { String(format: "0x%08X", UInt32(truncatingIfNeeded: $0)) }
    }
}

private struct FramePayload: Decodable {
    
    let index: Int?
    let function: String?
    let file: String?
    let lineno: Int?
    let address: FlexibleValue?
    let frameType: String?
    
    enum CodingKeys: String, CodingKey {
        case index, function, file, lineno, address
        case frameType = "frame_type"
    }
    
    var frame: NRFCloudCrashDetail.Frame {
        NRFCloudCrashDetail.Frame(index: index, function: function, file: file, line: lineno,
                                  address: address?.text, type: frameType)
    }
}

private struct ThreadPayload: Decodable {
    
    let tid: Int?
    let name: String?
    let state: String?
    let crashed: Bool?
    let current: Bool?
    let stackSize: Int?
    let stackUnused: Int?
    let stacktrace: [FramePayload]?
    let registers: [RegisterPayload]?
    
    enum CodingKeys: String, CodingKey {
        case tid, name, state, crashed, current, stacktrace, registers
        case stackSize = "stack_size"
        case stackUnused = "stack_unused"
    }
    
    var thread: NRFCloudCrashDetail.Thread {
        NRFCloudCrashDetail.Thread(id: tid ?? -1, name: name, state: state,
                                   isCrashed: crashed ?? false, isCurrent: current ?? false,
                                   stackSize: stackSize, stackUnused: stackUnused,
                                   frames: (stacktrace ?? []).map(\.frame),
                                   registers: (registers ?? []).map(\.register))
    }
}

private struct LogPayload: Decodable {
    
    let line: String?
    let level: String?
    
    var logLine: NRFCloudCrashDetail.LogLine {
        NRFCloudCrashDetail.LogLine(text: line ?? "", level: level)
    }
}
