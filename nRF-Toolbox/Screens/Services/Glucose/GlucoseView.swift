//
//  GlucoseView.swift
//  nRF Toolbox
//
//  Created by Dinesh Harjani on 6/6/25.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI
import Charts
import iOS_Common_Libraries

// MARK: - GlucoseView

struct GlucoseView: View {
    
    // MARK: Environment
    
    @Environment(GlucoseViewModel.self) private var viewModel: GlucoseViewModel
    
    // MARK: Properties
    
    enum ViewMode: RegisterValue, Hashable, Equatable, CustomStringConvertible, CaseIterable {
        case all, first, last
        
        var description: String {
            switch self {
            case .all:
                return "All Records"
            case .first:
                return "First Record"
            case .last:
                return "Last Record"
            }
        }
        
        var recordOperator: RecordOperator {
            switch self {
            case .all:
                return .allRecords
            case .first:
                return .firstRecord
            case .last:
                return .lastRecord
            }
        }
    }
    
    @State private var viewMode: ViewMode = .all
    
    // MARK: view
    
    var body: some View {
        switch viewMode {
        case .all:
            if viewModel.allRecords.hasItems {
                GlucoseAllRecordsChartView()
            } else {
                noDataView()
            }
        case .first:
            if let firstRecord = viewModel.firstRecord {
                GlucoseMeasurementView(sequenceNumber: firstRecord.sequenceNumber,
                                       measurement: firstRecord.measurement,
                                       dateString: firstRecord.toStringDate())
            } else {
                noDataView()
            }
        case .last:
            if let lastRecord = viewModel.lastRecord {
                GlucoseMeasurementView(sequenceNumber: lastRecord.sequenceNumber,
                                       measurement: lastRecord.measurement,
                                       dateString: lastRecord.toStringDate())
            } else {
                noDataView()
            }
        }
        
        InlinePicker(title: "Mode", systemImage: "square.on.square", selectedValue: $viewMode)
            .onChange(of: viewMode) {
                viewModel.requestRecords(viewMode.recordOperator)
            }
            .labeledContentStyle(.accentedContent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        switch viewMode {
                        case .all:
                            viewModel.requestRecords(.allRecords)
                        case .first:
                            viewModel.requestRecords(.firstRecord)
                        case .last:
                            viewModel.requestRecords(.lastRecord)
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
    }
    
    // MARK: noDataView()
    
    @ViewBuilder
    func noDataView() -> some View {
        if viewModel.inFlightRequest != nil {
            ProgressView()
                .fixedCircularProgressView()
                .centered()
                .listRowSeparator(.hidden)
        } else {
            NoContentView(title: "No Data", systemImage: "drop.fill", description: "No Glucose Level Data Available. You may press Button 2 on your DevKit to generate some Data.")
                .listRowSeparator(.hidden)
        }
    }
}
