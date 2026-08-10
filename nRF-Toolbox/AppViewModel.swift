//
//  AppViewModel.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 22/01/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import CombineExt
import iOS_Common_Libraries
import Foundation
import Combine
import SwiftData

@MainActor
@Observable
final class AppViewModel {
    
    private static let bufferSize = 1000

    private static let flushInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(500)
    private static let maxBatchSize = 250

    var logsSettings = LogsSettings()
    
    private let readDataSource: LogsReadDataSource
    private let writeDataSource: LogsWriteDataSource
    private var logCounter = 0
    private var clearTask: Task<(), Error>? = nil
 
    private let startLoggingSignal = PassthroughSubject<Void, Never>()
    private var replaySubject = ReplaySubject<LogItemDomain, Never>(bufferSize: bufferSize)
    private let contextManager: SwiftDataContextManager = SwiftDataContextManager.shared
    private let log = NordicLog(category: "AppViewModel", subsystem: "com.nordicsemi.nrf-toolbox")
    private var cancellables = Set<AnyCancellable>()
    
    @ObservationIgnored
    private lazy var parentPublisher: CurrentValueSubject<AnyPublisher<LogItemDomain, Never>, Never> = {
        return CurrentValueSubject<AnyPublisher<LogItemDomain, Never>, Never>(createNewPublisher(replaySubject))
    }()
    
    init() {
        self.readDataSource = LogsReadDataSource(modelContainer: contextManager.container!)
        self.writeDataSource = LogsWriteDataSource(modelContainer: contextManager.container!)
       
        observeLogs()
        observeLogsInsertion()
        refreshLogsCount()
    }
    
    private func observeLogs() {
        NordicLog.lastLog
            .filter { [weak self] _ in self?.logsSettings.isEnabled == true }
            .compactMap { $0 }
            .map { log in LogItemDomain(value: log.message, level: log.level.rawValue, timestamp: log.timestamp) }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] log in self?.replaySubject.send(log) } )
            .store(in: &cancellables)
    }

    func observeLogsInsertion() {
        parentPublisher
            .switchToLatest()
            .collect(.byTimeOrCount(DispatchQueue.main, Self.flushInterval, Self.maxBatchSize))
            .sink(receiveValue: { [weak self] logs in self?.insertRecords(logs) } )
            .store(in: &cancellables)
    }

    private func createNewPublisher(_ newReplySubject: ReplaySubject<LogItemDomain, Never>) -> AnyPublisher<LogItemDomain, Never> {
        replaySubject = newReplySubject

        return startLoggingSignal
            .flatMap { _ in newReplySubject }
            .eraseToAnyPublisher()
    }
    
    func insertRecords(_ items: [LogItemDomain]) {
        guard !items.isEmpty else { return }

        logCounter += items.count
        if logCounter > 100000 {
            clearLogs()
        }
        let writeDataSource = self.writeDataSource
        Task.detached(priority: .utility) {
            try await writeDataSource.insert(items)
        }
    }

    func clearLogs() {
        guard clearTask == nil else { return }
        parentPublisher.send(createNewPublisher(ReplaySubject<LogItemDomain, Never>(bufferSize: AppViewModel.bufferSize)))
        let cleanDataSource = LogsWriteDataSource(modelContainer: self.contextManager.container!)
        clearTask = Task.detached(priority: .userInitiated) {
            do {
                self.log.debug("Deleting all logs.")
                try await cleanDataSource.deleteAll()
                self.log.info("Successfully deleted logs.")
            } catch let error {
                self.log.error("Deleting logs failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                self.refreshLogsCount()
            }
        }
    }
    
    private func refreshLogsCount() {
        Task.detached { [weak self] in
            let result = (try? await self?.readDataSource.fetchCount()) ?? 0
            
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.logCounter = result
                self.startLoggingSignal.send(())
                self.clearTask = nil
            }
        }
    }
}
