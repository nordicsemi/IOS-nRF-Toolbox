//
//  SeenAdvertisements.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_BLE_Library_Mock
import iOS_Common_Libraries

final class SeenAdvertisements: @unchecked Sendable {
    
    private let lock = NSLock()
    private var seen = Set<String>()
    
    func logIfNew(id: UUID, name: String?, advertisement: AdvertisementData, to log: NordicLog) {
        let services = advertisement.serviceUUIDs?.map(\.uuidString).sorted().joined(separator: ",") ?? "-"
        let manufacturer = advertisement.manufacturerData?.hex ?? "-"
        let serviceData = advertisement.serviceData?
            .map { "\($0.key.uuidString)=\($0.value.hex)" }
            .sorted().joined(separator: ",") ?? "-"
        let advertisedID = advertisement.advertisedID() ?? "-"
        let line = "id=\(id.uuidString.prefix(8)) name=\(name ?? "<no name>") services=[\(services)] "
            + "manufacturer=\(manufacturer) serviceData=[\(serviceData)] advertisedID=\(advertisedID)"
        
        lock.lock()
        let isNew = seen.insert(line).inserted
        lock.unlock()
        
        if isNew {
            log.info("Advertisement \(line)")
        }
    }
}

private extension Data {
    
    var hex: String {
        map { String(format: "%02X", $0) }.joined()
    }
}
