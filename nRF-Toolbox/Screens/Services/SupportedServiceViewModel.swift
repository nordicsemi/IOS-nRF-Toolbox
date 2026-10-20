//
//  SupportedServiceViewModel.swift
//  nRF Toolbox
//
//  Created by Dinesh Harjani on 4/6/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

struct ErrorsHolder {
    var warning: LocalizedError?
    var error: LocalizedError?
    
    func hasAnyError() -> Bool {
        return warning != nil || error != nil
    }
}

// MARK: - SupportedServiceViewModel

protocol SupportedServiceViewModel {
    
    var errors: CurrentValueSubject<ErrorsHolder, Never> { get }
    
    var description: String { get }
    
    @ViewBuilder
    var attachedView: any View { get }
    
    func onConnect() async throws
    func onInitialized() async
    func onDisconnect()
}

extension SupportedServiceViewModel {
    
    func onInitialized() async {}
    
    func handleError(_ error: Error) {
        if case let serviceError as ServiceError = error {
            self.errors.value.error = serviceError
        } else if case let serviceWarning as ServiceWarning = error {
            self.errors.value.warning = serviceWarning
        } else {
            self.errors.value.error = ServiceError.unknown
        }
    }
}
