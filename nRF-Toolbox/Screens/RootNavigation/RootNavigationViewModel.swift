//
//  RootNavigationViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 16/11/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Combine 
import SwiftUI

// MARK: - RootNavigationViewModel

@MainActor
@Observable
final class RootNavigationViewModel {
    
    var selectedCategory: RootNavigationView.MenuCategory?
    var showAboutView: Bool = false
    
    static let shared = RootNavigationViewModel()
}

// MARK: - MenuCategory

extension RootNavigationView {
    
    private static let scannerUUID = UUID()
    private static let logsUUID = UUID()
    
    enum MenuCategory: Equatable, Hashable, Identifiable {
        case scanner
        case logs(LogsTab)
        case device(Device)
        
        var id: UUID {
            switch self {
            case .scanner:
                return scannerUUID
            case .logs:
                return logsUUID
            case .device(let device):
                return device.id
            }
        }
    }
}
