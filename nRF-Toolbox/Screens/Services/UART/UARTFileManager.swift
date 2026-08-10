//
//  UARTFileManager.swift
//  nRF Toolbox
//
//  Created by Sylwester Zieliński on 04/11/2025.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import Foundation
import iOS_Common_Libraries

class UARTFileManager {
    
    private let log = NordicLog(category: "UARTFileManager", subsystem: "com.nordicsemi.nrf-toolbox")
    
    private let parser = UARTPresetsXmlParser()
    
    func saveToFile(_ presets: UARTPresets) {
        log.debug("\(type(of: self)).\(#function)")
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("yourFileName.txt")
        
        do {
            let xml = try parser.toXml(presets)
            let data = xml.data(using: .utf8)!
            try data.write(to: fileURL, options: [.atomicWrite])
            log.debug("File saved successfully at: \(fileURL)")
        } catch {
            log.error("Error saving file: \(error.localizedDescription)")
        }
    }
}
