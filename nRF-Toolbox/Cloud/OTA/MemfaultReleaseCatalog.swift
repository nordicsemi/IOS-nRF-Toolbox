//
//  MemfaultReleaseCatalog.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 03/11/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import CryptoKit

struct CatalogRelease {
    let version: String
    let notes: String
    let filename: String
    let url: URL
    let md5: String
}

enum MemfaultReleaseCatalogError: LocalizedError {
    case notSignedIn
    case badResponse(Int)
    case invalidArtifactURL
    case md5Mismatch

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "Sign in and select a cloud project to check for firmware updates."
        case .badResponse(let code):
            "Downloading the firmware failed (HTTP \(code))."
        case .invalidArtifactURL:
            "The release artifact URL is invalid."
        case .md5Mismatch:
            "The downloaded firmware does not match the checksum published by Memfault."
        }
    }
}

enum MemfaultReleaseCatalog {

    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }

    static func download(_ release: CatalogRelease) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: release.url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw MemfaultReleaseCatalogError.badResponse(http.statusCode)
        }
        let digest = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(release.md5) == .orderedSame else {
            throw MemfaultReleaseCatalogError.md5Mismatch
        }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = directory.appendingPathComponent(release.filename)
        try data.write(to: fileURL)
        return fileURL
    }
}
