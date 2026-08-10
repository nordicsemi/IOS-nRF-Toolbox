//
//  SignalChartViewModel.swift
//  nRF-Toolbox
//
//  Created by Nick Kibysh on 18/10/2023.
//  Copyright © 2023 Nordic Semiconductor. All rights reserved.
//

import Combine
import Foundation
import iOS_BLE_Library_Mock
import iOS_Common_Libraries
import Charts

// MARK: - SignalChartViewModel

@MainActor final class SignalChartViewModel {
    let environment = Environment()
    let peripheral: Peripheral
    
    private var cancellable = Set<AnyCancellable>()
    
    private let log = NordicLog(category: "SignalChartViewModel",
                                subsystem: "com.nordicsemi.nrf-toolbox")
    
    // MARK: init
    
    init(peripheral: Peripheral) {
        self.peripheral = peripheral
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: startTimer
    
    func startTimer() {
        log.debug("\(type(of: self)).\(#function)")
        
        // Run Timer every 1 second
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .flatMap { [unowned self] _ in
                self.peripheral.readRSSI()
                    .timeout(0.9, scheduler: DispatchQueue.main)
            }
            .map { rssiNumber in
                Environment.ChartData(date: .now, signal: rssiNumber.intValue)
            }
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] completion in
                switch completion {
                case .finished:
                    log.debug("Finished Timer.")
                case .failure:
                    log.debug("Timer failure.")
                }
            } receiveValue: { [unowned self] newSignalItem in
                let diff = newSignalItem.date.timeIntervalSince1970 - environment.scrollPosition.timeIntervalSince1970
                if diff < CGFloat(Environment.visibleDomain + 5) || environment.chartData.isEmpty {
                    environment.scrollPosition = .now
                }
                environment.chartData.append(newSignalItem)

                if environment.chartData.count > Environment.capacity {
                    environment.chartData.removeFirst()
                }

                guard let first = environment.chartData.first,
                      let last = environment.chartData.last else { return }

                var minSignal = first.signal
                var maxSignal = minSignal
                for item in environment.chartData.dropFirst() {
                    if item.signal < minSignal { minSignal = item.signal }
                    if item.signal > maxSignal { maxSignal = item.signal }
                }

                environment.lowest = minSignal - 5
                environment.highest = maxSignal + 5
                environment.minDate = first.date.addingTimeInterval(-2)
                environment.maxDate = last.date.addingTimeInterval(2)
            }
            .store(in: &cancellable)
    }
    
    // MARK: stopTimer
    
    func stopTimer() {
        log.debug("\(type(of: self)).\(#function)")
        cancellable.removeAll()
    }
}

// MARK: - Environment

extension SignalChartViewModel {
    
    @MainActor
    @Observable
    final class Environment {
        
        struct ChartData: Identifiable {
            let date: Date
            let signal: Int
            var id: TimeInterval { date.timeIntervalSince1970 }
        }
        
        // MARK: Constants
        
        static let visibleDomain = 60
        fileprivate static let capacity = 180
        
        // MARK: Properties
        
        fileprivate(set) var chartData: [ChartData] = []
        var scrollPosition = Date()
        
        fileprivate(set) var lowest: Int = -100
        fileprivate(set) var highest: Int = -40
        
        var minDate: Date = .distantPast
        var maxDate: Date = .distantFuture
        
        private let log = NordicLog(category: "SignalChartViewModel.Environment",
                                    subsystem: "com.nordicsemi.nrf-toolbox")
        
        // MARK: init
        
        init(chartData: [ChartData] = []) {
            self.chartData = chartData
            self.chartData.reserveCapacity(Self.capacity)
            assert(Self.capacity >= Self.visibleDomain)
            log.debug("\(type(of: self)).\(#function)")
        }
        
        deinit {
            log.debug("\(type(of: self)).\(#function)")
        }
    }
}
