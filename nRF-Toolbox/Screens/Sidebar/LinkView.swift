//
//  LinkView.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 06/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

public struct LinkView: View {
    
    @Environment(\.openURL) private var openURL
    
    let link: Link
    let title: String
    let systemImage: String
    let url: String
    
    public var body: some View {
        Button {
            NordicAnalytics.logEvent(LinkOpenEvent(link: link))

            guard let url = URL(string: url) else { return }
            openURL(url)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}
