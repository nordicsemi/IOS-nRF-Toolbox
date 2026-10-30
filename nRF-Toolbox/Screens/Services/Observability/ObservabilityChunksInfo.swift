//
//  ObservabilityChunksInfo.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOSOtaLibrary

// MARK: - ObservabilityChunksInfo

struct ObservabilityChunksInfo {

    // MARK: Properties

    fileprivate struct Key: Hashable {
        let sequenceNumber: UInt8
        let timestamp: Date
        let data: Data
    }

    private var pendingChunks: [Key: Int] = [:]
    private var uploadedKeys: Set<Key> = []

    private(set) var uploadedCount: Int = 0
    private(set) var uploadedBytes: Int = 0

    var pendingCount: Int { pendingChunks.count }
    var pendingBytes: Int { pendingChunks.values.reduce(0, +) }

    // MARK: processChunk()

    mutating func processChunk(_ chunk: ObservabilityChunk) {
        switch chunk.status {
        case .pendingUpload:
            pending(chunk)
        case .success:
            uploaded(chunk)
        default:
            break
        }
    }

    // MARK: pending()

    mutating func pending(_ chunk: ObservabilityChunk) {
        let key = Key(chunk)
        guard !uploadedKeys.contains(key) else { return }
        pendingChunks[key] = chunk.data.count
    }

    // MARK: uploaded()

    mutating func uploaded(_ chunk: ObservabilityChunk) {
        let key = Key(chunk)
        pendingChunks.removeValue(forKey: key)
        guard uploadedKeys.insert(key).inserted else { return }

        uploadedCount += 1
        uploadedBytes += chunk.data.count
    }

    // MARK: pendingBytesString

    func pendingBytesString() -> String {
        "\(pendingCount) chunk(s), \(Self.formatted(bytes: pendingBytes))"
    }

    // MARK: uploadedBytesString

    func uploadedBytesString() -> String {
        "\(uploadedCount) chunk(s), \(Self.formatted(bytes: uploadedBytes))"
    }

    // MARK: Private

    private static func formatted(bytes: Int) -> String {
        if #available(iOS 16.0, macCatalyst 16.0, macOS 13.0, *) {
            let measurement = Measurement<UnitInformationStorage>(value: Double(bytes), unit: .bytes)
            return measurement.formatted(.byteCount(style: .file))
        } else {
            return "\(bytes) bytes"
        }
    }
}

extension ObservabilityChunksInfo.Key {

    fileprivate init(_ chunk: ObservabilityChunk) {
        self.init(sequenceNumber: chunk.sequenceNumber, timestamp: chunk.timestamp, data: chunk.data)
    }
}
