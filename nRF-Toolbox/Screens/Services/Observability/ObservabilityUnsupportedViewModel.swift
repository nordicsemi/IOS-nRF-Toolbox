//
//  ObservabilityUnsupportedViewModel.swift
//  nRF-Toolbox
//
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - ObservabilityUnsupportedViewModel

@Observable
final class ObservabilityUnsupportedViewModel: SupportedServiceViewModel {

    // MARK: Properties

    var errors: CurrentValueSubject<ErrorsHolder, Never> = CurrentValueSubject<ErrorsHolder, Never>(ErrorsHolder())

    // MARK: description

    var description: String {
        "Observability"
    }

    // MARK: attachedView

    var attachedView: any View {
        ObservabilityUnsupportedView()
    }

    // MARK: onConnect() / onDisconnect()

    func onConnect() async { }

    func onDisconnect() { }
}
