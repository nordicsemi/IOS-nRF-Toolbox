//
//  ServiceBadgeGroup.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 12/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries
import iOS_Bluetooth_Numbers_Database

// MARK: - ServiceBadgeGroup

struct ServiceBadgeGroup: View {
    
    private let services: [Service]
    
    // MARK: init
    
    init(_ services: Set<Service>) {
        self.services = services
            .map({ $0 })
            .filter(\.isSupported)
            .sorted(by: { a, b in
                a.name < b.name
            })
    }
    
    // MARK: view

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(alignment: .center, spacing: 8) {
                    ForEach(rows[rowIndex].indices, id: \.self) { itemIndex in
                        rows[rowIndex][itemIndex]
                    }
                }
            }
        }
    }

    // MARK: rows

    private var rows: [[AnyView]] {
        let allBadges = badgeViews
        return stride(from: 0, to: allBadges.count, by: 2).map {
            Array(allBadges[$0..<min($0 + 2, allBadges.count)])
        }
    }

    // MARK: badgeViews

    private var badgeViews: [AnyView] {
        var views = services.map { service in
            AnyView(
                BadgeView(image: service.systemImage, name: service.displayName, color: service.color ?? .primary)
                    .lineLimit(1)
            )
        }

        let overflowCount = services.reduce(0, { $0 + ($1.isSupported ? 0 : 1) })
        if overflowCount > 0 {
            views.append(AnyView(BadgeView(name: otherServiceString(count: overflowCount))))
        }
        return views
    }
    
    // MARK: otherServiceString(count:)
    
    private func otherServiceString(count: Int) -> String {
        let prefixSymbol = count == services.count ? "" : " +"
        
        let formatString: String = NSLocalizedString("service_count", comment: "")
        let resultString: String = String.localizedStringWithFormat(formatString, count)
        return prefixSymbol + resultString
    }
}
