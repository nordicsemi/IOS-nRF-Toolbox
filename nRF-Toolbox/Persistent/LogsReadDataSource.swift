//
//  LogsReadDataSource.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 21/01/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftData
import Foundation
import iOS_Common_Libraries

@ModelActor
actor LogsReadDataSource {
    
    private let log = NordicLog(category: "LogsReadDataSource", subsystem: "com.nordicsemi.nrf-toolbox")
    
    func fetchCount() throws -> Int {
        return try modelContext.fetchCount(FetchDescriptor<LogDb>())
    }
    
    func fetchAll() throws -> [LogItemDomain] {
        return try fetch(searchText: "", logLevel: .error)
    }
    
    func fetch(searchText: String, logLevel: LogLevel) throws -> [LogItemDomain] {
        try modelContext
            .fetch(getFetchDescriptor(searchText: searchText, logLevel: logLevel))
            .map { LogItemDomain(from: $0) }
    }
    
    func fetch(searchText: String, logLevel: LogLevel, limit: Int) throws -> [LogItemDomain] {
        var descriptor = getFetchDescriptor(searchText: searchText, logLevel: logLevel)
        descriptor.fetchLimit = limit
        
        return try modelContext
            .fetch(descriptor)
            .map { LogItemDomain(from: $0) }
    }
    
    func fetch(searchText: String, logLevel: LogLevel, offset: Int, amountPerPage: Int) throws -> [LogItemDomain] {
        var descriptor = getFetchDescriptor(searchText: searchText, logLevel: logLevel)
        descriptor.fetchLimit = amountPerPage
        descriptor.fetchOffset = offset

        let fetched = try modelContext.fetch(descriptor)

        return fetched.map {
            LogItemDomain(from: $0)
        }
    }

    /// Fetches only records newer than `timestamp`, oldest-first, so they can be
    /// appended directly to the end of an already oldest-to-newest ordered list.
    func fetch(searchText: String, logLevel: LogLevel, newerThan timestamp: Date) throws -> [LogItemDomain] {
        let descriptor = FetchDescriptor<LogDb>(
            predicate: #Predicate { log in
                (searchText.isEmpty ? true : log.value.localizedStandardContains(searchText)) && log.level <= logLevel.rawValue && log.timestamp > timestamp
            },
            sortBy: [
                SortDescriptor(\.timestamp, order: .forward)
            ]
        )

        return try modelContext
            .fetch(descriptor)
            .map { LogItemDomain(from: $0) }
    }

    func getFetchDescriptor(searchText: String, logLevel: LogLevel) -> FetchDescriptor<LogDb> {
        return FetchDescriptor<LogDb>(
            predicate: #Predicate { log in
                (searchText.isEmpty ? true : log.value.localizedStandardContains(searchText)) && log.level <= logLevel.rawValue
            },
            sortBy: [
                SortDescriptor(\.timestamp, order: .reverse)
            ]
        )
    }
}
