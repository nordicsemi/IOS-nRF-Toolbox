//
//  RestoringCentralManagerDelegate.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Combine
import iOS_BLE_Library_Mock

// MARK: - RestoringCentralManagerDelegate

final class RestoringCentralManagerDelegate: ReactiveCentralManagerDelegate {
    
    static let restoreIdentifier = "com.nordicsemi.nrf-toolbox.central"
    
    let restoredPeripheralsSubject = CurrentValueSubject<[CBPeripheral], Never>([])
    
    // MARK: CBCentralManagerDelegate
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        restoredPeripheralsSubject.send(peripherals)
    }
}
