//
//  CloudLog.swift
//  nRF-Toolbox
//
//  Created by Sylwester Zielinski on 26/10/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import iOS_Common_Libraries

extension NordicLog {
    
    static func cloud(_ category: String) -> NordicLog {
        NordicLog(category: category, subsystem: "com.nordicsemi.nrf-toolbox")
    }
}
