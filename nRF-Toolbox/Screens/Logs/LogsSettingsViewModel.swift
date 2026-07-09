//
//  LogsSettingsViewModel.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 16/01/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import Combine
import Foundation
import iOS_Common_Libraries
import SwiftData

/// Tells the screen *why* `logs` just changed, so it can decide how (or whether)
/// to move the scroll position in response.
enum LogsUpdateReason {
    /// Search/level filter changed — the whole list was replaced.
    case filterReset
    /// New logs arrived and were appended at the end (list is oldest-first).
    case newDataAppended
    /// An older page was loaded and prepended at the front.
    case olderPagePrepended
}

@MainActor
@Observable
class LogsSettingsViewModel {

    private let log = NordicLog(category: "LogsSettingsScreen", subsystem: "com.nordicsemi.nrf-toolbox")

    var logs: [LogItemDomain]? = nil
    var lastUpdateReason: LogsUpdateReason = .filterReset
    var logsMeta: LogsMeta? = nil
    var isLoading: Bool = false
    
    private let searchTextSubject = CurrentValueSubject<String, Never>("")
    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }
    private let selectedLogLevelSubject = CurrentValueSubject<LogLevel, Never>(.debug)
    var selectedLogLevel: LogLevel = .debug {
        didSet {
            selectedLogLevelSubject.send(selectedLogLevel)
        }
    }
    
    private let readDataSource: LogsReadDataSource

    private let itemsPerPage: Int = 100
    private var canLoadOlder: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    private var activeLoadTask: Task<Void, Never>? = nil
    
    // MARK: init
    
    init(container: ModelContainer) {
        log.debug("\(type(of: self)).\(#function)")
        self.readDataSource = LogsReadDataSource(modelContainer: container)
        setupObservers()
        fetchLogsCount()
        reload()
    }

    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    private func setupObservers() {
        Publishers.CombineLatest(searchTextSubject, selectedLogLevelSubject)
            .dropFirst()
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .removeDuplicates { prev, curr in
                prev.0 == curr.0 && prev.1 == curr.1
            }
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: ModelContext.didSave)
            .throttle(for: .seconds(1.0), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.appendNewData()
            }
            .store(in: &cancellables)
    }

    func reload() {
        guard !isLoading else { return }
        activeLoadTask?.cancel()

        isLoading = true
        canLoadOlder = true

        let currentSearch = searchText
        let currentLevel = selectedLogLevel
        let limit = itemsPerPage

        activeLoadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let records = try? await self.readDataSource.fetch(
                searchText: currentSearch,
                logLevel: currentLevel,
                limit: limit
            )

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.lastUpdateReason = .filterReset
                self.logs = records.map { Array($0.reversed()) }
                self.isLoading = false
                self.fetchLogsCount()
            }
        }
    }

    private func appendNewData() {
        guard !isLoading else { return }
        isLoading = true

        let currentSearch = searchText
        let currentLevel = selectedLogLevel
        let knownNewestTimestamp = logs?.last?.timestamp
        let limit = itemsPerPage

        activeLoadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let newRecords: [LogItemDomain]?
            if let knownNewestTimestamp {
                newRecords = try? await self.readDataSource.fetch(
                    searchText: currentSearch,
                    logLevel: currentLevel,
                    newerThan: knownNewestTimestamp
                )
            } else {
                let records = try? await self.readDataSource.fetch(
                    searchText: currentSearch,
                    logLevel: currentLevel,
                    limit: limit
                )
                newRecords = records.map { Array($0.reversed()) }
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }

                if let newRecords = newRecords, !newRecords.isEmpty {
                    self.lastUpdateReason = .newDataAppended
                    if self.logs == nil {
                        self.logs = newRecords
                    } else {
                        self.logs?.append(contentsOf: newRecords)
                    }
                }
                self.isLoading = false
                self.fetchLogsCount()
            }
        }
    }

    func loadOlderPage() {
        guard !isLoading, canLoadOlder, let currentCount = logs?.count else { return }
        isLoading = true

        let currentSearch = searchText
        let currentLevel = selectedLogLevel
        let offset = currentCount
        let amount = itemsPerPage

        activeLoadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let olderRecords = try? await self.readDataSource.fetch(
                searchText: currentSearch,
                logLevel: currentLevel,
                offset: offset,
                amountPerPage: amount
            )

            await MainActor.run {
                guard !Task.isCancelled else { return }

                if let olderRecords = olderRecords, !olderRecords.isEmpty {
                    self.lastUpdateReason = .olderPagePrepended
                    self.logs = olderRecords.reversed() + (self.logs ?? [])
                } else {
                    self.canLoadOlder = false
                }
                self.isLoading = false
            }
        }
    }

    private nonisolated func fetchLogsCount() {
        Task.detached { [weak self] in
            guard let self = self else { return }
            let count = try? await self.readDataSource.fetchCount()
            let meta = count != nil ? LogsMeta(size: Double(count!)) : nil
            
            await MainActor.run {
                self.logsMeta = meta
            }
        }
    }
}
