//
//  NRFCloudCrash.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation

struct NRFCloudCrash: Identifiable, Decodable, Equatable {
    
    let id: Int
    let capturedDate: Date?
    let title: String?
    let reason: String?
    let release: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, title, reason
        case capturedDate = "captured_date"
        case softwareVersion = "software_version"
    }
    
    private enum VersionKeys: String, CodingKey {
        case version
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        capturedDate = (try? container.decode(String.self, forKey: .capturedDate)).flatMap(Date.init(memfault:))
        title = try? container.decode(String.self, forKey: .title)
        reason = try? container.decode(String.self, forKey: .reason)
        release = (try? container.nestedContainer(keyedBy: VersionKeys.self, forKey: .softwareVersion))
            .flatMap { try? $0.decode(String.self, forKey: .version) }
    }
}

extension Date {
    
    init?(memfault text: String) {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: text) ?? plain.date(from: text) else { return nil }
        self = date
    }
}
