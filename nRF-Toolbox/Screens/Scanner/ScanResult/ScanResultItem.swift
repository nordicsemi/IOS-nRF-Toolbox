//
//  ScanResultItem.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 10/07/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import iOS_Bluetooth_Numbers_Database

// MARK: - ScanResultItem

struct ScanResultItem: View {
    
    // MARK: Properties
    
    private let name: String?
    private let services: Set<Service>
    private let inProgress: Bool
    private let isScanner: Bool
    private let hasSupportedServices: Bool
    
    // MARK: init
    
    init(name: String?, services: Set<Service>, showProgress: Bool = false, isScanner: Bool = true) {
        self.name = name
        self.services = services
        self.inProgress = showProgress
        self.isScanner = isScanner
        self.hasSupportedServices = services.contains(where: \.isSupported)
    }
    
    // MARK: view
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(name ?? "Unnamed Device")
                        .foregroundColor(isScanner ? (name == nil ? .secondary : .primary) : nil)
                    
                    if hasSupportedServices {
                        ServiceBadgeGroup(services)
                    }
                }
            } icon: {
                Image(systemName: "cpu")
                    .foregroundColor(isScanner ? Color.universalAccentColor : nil)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, 8)
            .padding(.bottom, hasSupportedServices ? 6 : 0)
            
            ProgressView()
                .opacity(inProgress ? 1.0 : 0.0)
        }
    }
}
