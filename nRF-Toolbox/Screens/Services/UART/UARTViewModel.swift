//
//  UARTViewModel.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 14/4/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine
import CoreBluetoothMock
import iOS_BLE_Library_Mock
import iOS_Bluetooth_Numbers_Database
import iOS_Common_Libraries

// MARK: - UARTViewModel

@Observable
final class UARTViewModel: SupportedServiceViewModel {
    
    // MARK: Published
    
    private(set) var messages: [UARTMessage] = []
    var newMessage: String = ""
    
    private(set) var presets: [UARTPresets] = [.none]
    var selectedPresets = UARTPresets.none
    var editedPresets: UARTPresets = UARTPresets.none
    var showEditPresetsSheet = false
    var editCommandIndex: Int = 0
    var showEditPresetSheet: Bool = false
    
    var showFileExporter = false
    var pendingChanges = false
    
    var alertMessage: String = ""
    var showAlert: Bool = false
    
    var isPlayInProgress: Bool = false
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())
    
    // MARK: Private Properties
    
    private let peripheral: Peripheral
    private let characteristics: [CBCharacteristic]
    private var uartRX: CBCharacteristic!
    private var uartTX: CBCharacteristic!
    
    private let fileManager = UARTFileManager()
    private let parser = UARTPresetsXmlParser()
    private var playTask: Task<(), Never>?
    
    private var cancellables: Set<AnyCancellable>
    private let log = NordicLog(category: "UARTViewModel", subsystem: "com.nordicsemi.nrf-toolbox")

    // MARK: init
    
    init(peripheral: Peripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral
        self.characteristics = characteristics
        self.cancellables = Set<AnyCancellable>()
        log.debug("\(type(of: self)).\(#function)")
        loadPresetsFromJsonFile()
    }
    
    // MARK: deinit
    
    deinit {
        log.debug("\(type(of: self)).\(#function)")
    }
    
    // MARK: description
    
    var description: String {
        "UART"
    }
    
    // MARK: attachedView
    
    var attachedView: any View {
        return UARTView()
            .environment(self)
    }
    
    // MARK: onConnect()
    
    @MainActor
    func onConnect() async {
        log.debug("\(type(of: self)).\(#function)")
        do {
            try await initializeCharacteristics()
            log.info("UART service has set up successfully.")
        } catch {
            log.error("UART service set up failed.")
            log.error("Error \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    @MainActor
    func initializeCharacteristics() async throws {
        log.debug("\(type(of: self)).\(#function)")
        let characteristics: [Characteristic] = [
            .nordicsemiUartRx, .nordicsemiUartTx
        ]
        let cbCharacteristics: [CBCharacteristic] = self.characteristics.filter { cbChar in
            characteristics.contains { $0.uuid == cbChar.uuid }
        }
        
        uartRX = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.nordicsemiUartRx.uuid)
        uartTX = cbCharacteristics.first(where: \.uuid, isEqualsTo: Characteristic.nordicsemiUartTx.uuid)
        
        guard let uartTX else {
            log.error("Transmit characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        guard uartRX != nil else {
            log.error("Receive characteristic is missing.")
            throw ServiceError.noMandatoryCharacteristic
        }
        
        listenToIncomingMessages(uartTX)
        let txEnable = try await peripheral.setNotifyValue(true, for: uartTX).firstValue
        guard txEnable else {
            log.error("Notifications not enabled.")
            throw ServiceError.notificationsNotEnabled
        }
        log.debug("\(#function) tx.setNotifyValue(true): \(txEnable)")
    }
    
    // MARK: onDisconnect()
    
    func onDisconnect() {
        log.debug("\(type(of: self)).\(#function)")
        uartRX = nil
        uartTX = nil
        cancellables.removeAll()
    }
}

// MARK: API

extension UARTViewModel {
    
    @MainActor
    private func send(_ data: Data) async {
        guard let uartRX else { return }
        log.debug("\(type(of: self)).\(#function)")
        
        do {
            if let dataAsString = String(data: data, encoding: .utf8) {
                let cleanText = dataAsString.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
                log.info("Sending new message: \(cleanText).")
                let uartMessage = UARTMessage(text: cleanText, source: .user, previousMessage: messages.last)
                messages.append(uartMessage)
            } else {
                let rawBytes = "\(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing, .upperCase]))"
                log.info("Sending new byte message.")
                let uartMessage = UARTMessage(text: rawBytes, source: .user, previousMessage: messages.last)
                messages.append(uartMessage)
            }
            
            try await peripheral.writeValueWithResponse(data, for: uartRX).firstValue
            log.info("Message successfully sent.")
        } catch {
            log.debug("\(#function) Error: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    func listenToIncomingMessages(_ rxCharacteristic: CBCharacteristic) {
        log.debug("\(type(of: self)).\(#function)")
        peripheral.listenValues(for: rxCharacteristic)
            .compactMap { [log] data -> UARTMessage? in
                log.debug("Received Data \(data.hexEncodedString(options: [.prepend0x, .twoByteSpacing])) (\(data.count) bytes)")
                guard let string = String(data: data, encoding: .utf8) else {
                    return nil
                }
                let cleanString = string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
                
                log.info("Received message: \(cleanString)")
                return UARTMessage(text: cleanString, source: .other, previousMessage: nil)
            }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { [log] _ in
                log.debug("Completion")
            }, receiveValue: { incoming in
                let newMessage = UARTMessage(text: incoming.text, source: incoming.source, previousMessage: self.messages.last)
                self.messages.append(newMessage)
            })
            .store(in: &cancellables)
    }
    
    @MainActor
    func clearReceivedMessages() {
        messages = []
    }
    
    @MainActor
    func newPresets(named: String) {
        NordicAnalytics.logEvent(UARTCreateConfigurationEvent())
        let newPresets = UARTPresets(named)
        presets.append(newPresets)
        selectedPresets = newPresets
        savePresetsToXmlFile()
        savePresetsToJsonFile()
    }
    
    @MainActor
    func runCommand(_ command: UARTPreset) {
        log.debug("\(type(of: self)).\(#function)")
        guard let data = command.data else { return }
        NordicAnalytics.logEvent(UARTSendEvent(mode: .preset))
        Task {
            await send(data)
        }
    }
    
    @MainActor
    func sendMessage() {
        let data = Data(newMessage.utf8)
        newMessage = ""
        NordicAnalytics.logEvent(UARTSendEvent(mode: .text))
        Task {
            await send(data)
        }
    }
    
    func startEdit() {
        editedPresets = selectedPresets
        savePresetsToXmlFile(notifyUser: false)
    }
    
    @MainActor
    func savePresets() {
        log.debug("\(type(of: self)).\(#function)")
        guard editedPresets != .none, let i = presets.firstIndex(of: selectedPresets)  else { return }
        
        presets[i] = editedPresets
        selectedPresets = editedPresets
        editedPresets = .none
        savePresetsToXmlFile()
        savePresetsToJsonFile()
        showEditPresetsSheet = false
    }
    
    @MainActor
    func updateSelectedPresetsName(_ name: String) {
        guard editedPresets != .none else { return }
        
        self.editedPresets = UARTPresets(name, commands: editedPresets.commands)
    }
    
    @MainActor
    func updateSelectedPresetCommand(_ command: UARTPreset) {
        guard editedPresets != .none else { return }
        
        var updatedCommands = editedPresets.commands
        updatedCommands[command.id] = command
        self.editedPresets = UARTPresets(editedPresets.name, commands: updatedCommands)
    }
    
    @MainActor
    func updateSelectedPresetsSequence(_ sequence: [UARTSequenceItem]) {
        guard editedPresets != .none else { return }
        
        self.editedPresets = UARTPresets(editedPresets.name, commands: editedPresets.commands, sequence: sequence)
    }
    
    @MainActor
    func deleteSelectedPresets() {
        guard selectedPresets != .none else { return }
        if let i = presets.firstIndex(of: selectedPresets) {
            presets.remove(at: i)
            selectedPresets = presets.first ?? .none
        }
        savePresetsToJsonFile()
    }
    
    func savePresetsToJsonFile() {
        log.debug("\(type(of: self)).\(#function)")
        let copy = presets
        Task.detached {
            do {
                try Self.writeBack(presets: copy)
            } catch {
                self.log.debug("Error while storing presets to a local cache - \(error.localizedDescription)")
            }
        }
    }
    
    func loadPresetsFromJsonFile() {
        log.debug("\(type(of: self)).\(#function)")
        Task.detached {
            do {
                if let savedPresets = try Self.read() {
                    self.presets = savedPresets
                    if self.presets.count >= 2 {
                        self.selectedPresets = savedPresets[1]
                    }
                }
            } catch {
                self.log.debug("Error while importing presets from a local cache - \(error.localizedDescription)")
            }
        }
    }
    
    func savePresetsToXmlFile(notifyUser: Bool = true) {
        log.debug("\(type(of: self)).\(#function)")
        Task.detached {
            let text = (try? self.parser.toXml(self.selectedPresets)) ?? ""
            let url = self.selectedPresets.url

            do {
                try text.write(to: url, atomically: true, encoding: .utf8)

                if (notifyUser) {
                    self.alertMessage = "Presets have been saved!"
                    self.showAlert = true
                }
            } catch {
                if (notifyUser) {
                    self.alertMessage = "An error occured while saving presets. Please try again."
                    self.showAlert = true
                    self.log.debug("An error occured while saving presets: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func importPresets(result: Result<[URL], any Error>) {
        log.debug("\(type(of: self)).\(#function)")
        switch result {
        case .success(let urls):
            do {
                let url = urls.first!
                
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                
                guard didAccess else {
                    alertMessage = "Cannot access a file. Please try again."
                    showAlert = true
                    return
                }

                let data = try Data(contentsOf: url)
                let presets = try parser.fromXml(data)
                self.presets.append(presets)
                
                savePresetsToJsonFile()
                
                selectedPresets = presets
                alertMessage = "Presets have been successfully imported!"
                showAlert = true
            } catch {
                alertMessage = "An error occured while importing presets. Please try again."
                showAlert = true
                log.debug("Error while laoding presets: \(error.localizedDescription)")
            }
        case .failure(let error):
            alertMessage = "An error occured while importing presets. Please try again."
            showAlert = true
            log.debug("File importer exited with error: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        playTask?.cancel()
    }
    
    @MainActor
    func play() {
        let sequence = selectedPresets.sequence
        playTask = Task {
            isPlayInProgress = true
            for item in sequence {
                if Task.isCancelled {
                    isPlayInProgress = false
                    return
                }
                switch (item) {
                case .command(let preset):
                    runCommand(preset)
                    break
                case .delay(let delay):
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                    break
                }
            }
            isPlayInProgress = false
        }
    }
}

// MARK: - Error

extension UARTViewModel {
    
    enum Err: Error {
        case unableToTurnOnNotifications
        case unableToEncodeString(_ string: String)
    }
}

// MARK: - CBUUID

extension CBUUID {
    
    static let nordicsemiUART = CBUUID(service: .nordicsemiUART)
}
