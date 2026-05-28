//
//  CGMSView.swift
//  nRF-Toolbox
//
//  Created by Dinesh Harjani on 1/4/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import iOS_Common_Libraries

// MARK: - CGMSView

struct CGMSView: View {
    
    // MARK: EnvironmentObject
    
    @Environment(CGMSViewModel.self) private var viewModel: CGMSViewModel
    
    // MARK: Properties
    
    @State private var mode: GlucoseView.ViewMode = .all
    
    // MARK: view
    
    var body: some View {
        switch mode {
        case .all:
            if viewModel.records.hasItems {
                CGMSAllRecordsChartView()
            } else {
                noDataView()
            }
        case .first:
            if let firstRecord = viewModel.firstRecord {
                GlucoseMeasurementView(sequenceNumber: firstRecord.timeOffset,
                                       measurement: firstRecord.measurement,
                                       dateString: firstRecord.toStringDate())
            } else {
                noDataView()
            }
        case .last:
            if let lastRecord = viewModel.lastRecord {
                GlucoseMeasurementView(sequenceNumber: lastRecord.timeOffset,
                                       measurement: lastRecord.measurement,
                                       dateString: lastRecord.toStringDate())
            } else {
                noDataView()
            }
        }
        
        InlinePicker(title: "Mode", systemImage: "square.on.square", selectedValue: $mode)
            .onChange(of: mode) {
                Task {
                    await viewModel.requestRecords(mode.recordOperator)
                }
            }
            .labeledContentStyle(.accentedContent)
    }
    
    @ViewBuilder
    func noDataView() -> some View {
        if viewModel.inFlightRequest != nil {
            ProgressView()
                .fixedCircularProgressView()
                .centered()
                .listRowSeparator(.hidden)
        } else {
            NoContentView(title: "No Data", systemImage: "drop.fill", description: "No Continuous Glucose Measurement Data Available.")
                .listRowSeparator(.hidden)
        }
    }
}
