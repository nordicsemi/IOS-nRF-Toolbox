//
//  LogsPreviewScreen.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 13/01/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftData
import SwiftUI
import iOS_Common_Libraries

struct LogsPreviewScreen: View {
    
    @Environment(LogsSettingsViewModel.self) var viewModel: LogsSettingsViewModel
    
    @FocusState private var isFocused: Bool
    
    @State private var followLatest = true
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var pendingOlderPageAnchorID: LogItemDomain.ID?
    
    var body: some View {
        @Bindable var viewModel = viewModel
        VStack {
            HStack {
                ZStack(alignment: .leading) {
                    
                    BlinkingCursorView().hidden(!viewModel.searchText.isEmpty)

                    HStack(spacing: 0) {
                        TextField("Search logs", text: $viewModel.searchText, prompt: Text("Search logs...")).focused($isFocused).tint(.clear)
                        BlinkingCursorView().padding(.leading, 6).hidden()
                    }
                    
                    HStack(spacing: 0) {
                        Text(viewModel.searchText).lineLimit(1).hidden()
                        BlinkingCursorView().padding(.leading, 2).hidden(viewModel.searchText.isEmpty)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemGray5))
                )
                
                Picker("Color", selection: $viewModel.selectedLogLevel, content: {
                    ForEach(LogLevel.allCases) { log in
                        LogLevelItem(level: log).tag(log)
                    }
                }, currentValueLabel: {
                    LogLevelItem(level: viewModel.selectedLogLevel)
                })
                .tint(viewModel.selectedLogLevel.color)
                
                Button {
                    followLatest.toggle()
                    if followLatest {
                        scrollPosition.scrollTo(edge: .bottom)
                    }
                } label: {
                    ZStack {
                        Image(systemName: followLatest ? "lock" : "lock.slash")
                    }.frame(width: 24, height: 24)
                }
            }
            .padding()

            LoadingListContainer(data: viewModel.logs) { logs in
                ScrollView {
                    LazyVStack {
                        ForEach(logs, id: \.id) { log in
                            LogItem(log: log)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .onAppear {
                                    guard logs.first == log else { return }
                                    pendingOlderPageAnchorID = log.id
                                    viewModel.loadOlderPage()
                                }

                            if logs.last != log {
                                Separator()
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .onAppear {
                    scrollPosition.scrollTo(edge: .bottom)
                }
                .searchable(text: $viewModel.searchText)
                .defaultScrollAnchor(.bottom)
                .scrollPosition($scrollPosition)
                .onChange(of: viewModel.logs) { _, newValue in
                    guard newValue != nil else { return }

                    switch viewModel.lastUpdateReason {
                    case .filterReset:
                        scrollPosition.scrollTo(edge: .bottom)

                    case .newDataAppended:
                        if followLatest {
                            scrollPosition.scrollTo(edge: .bottom)
                        }

                    case .olderPagePrepended:
                        if let anchorID = pendingOlderPageAnchorID {
                            pendingOlderPageAnchorID = nil
                            scrollPosition.scrollTo(id: anchorID, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

private struct LoadingListContainer<Data, Content: View>: View {
    
    let data: [Data]?
    @ViewBuilder let content: ([Data]) -> Content
    
    var body: some View {
        if let data = data {
            if data.isEmpty {
                Text("No records")
                    .foregroundColor(Color(.systemGray2))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content(data)
            }
        } else {
            ProgressView()
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct Separator: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
            .background(Color(.systemGray5))
    }
}

private struct LogItem: View {
    
    let log: LogItemDomain
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(log.displayDate)
                    .font(.system(.caption2, design: .monospaced))
                
                Spacer()
                
                LogLevelItem(level: log.logLevel)
            }
            
            Text(log.value)
                .foregroundColor(log.logLevel.color)
                .font(.system(.footnote, design: .monospaced))
        }
    }
}

private struct LogLevelItem: View {
    
    let level: LogLevel
    
    var body: some View {
        Text(level.name)
            .foregroundColor(Color.white)
            .font(.system(.caption2, design: .monospaced))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(level.color)
            )
    }
}
