//
//  MissingCharacteristicsView.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 19/12/2025.
//  Copyright © 2025 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct MissingCharacteristicsView : View {
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .padding(30)
                .background(Circle().fill(Color.yellow))
                .padding(30)
                .padding(.bottom, 16)
            
            Text("Missing characteristics")
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            Text("Connection to the peripheral was successful, but the advertised characteristics could not be found.")
                .font(.footnote)
                .padding(.bottom, 32)
                .lineSpacing(10)
            
            Text("Troubleshooting")
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            Text("If you installed new firmware on your old peripheral, the old characteristics might still be cached on your phone. Try toggling Bluetooth off and on in your phone's settings, then reconnect to the peripheral.")
                .font(.footnote)
                .lineSpacing(10)
                .padding(.bottom, 16)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }.padding(.vertical, 16)
    }
}

#Preview {
    MissingCharacteristicsView()
}
