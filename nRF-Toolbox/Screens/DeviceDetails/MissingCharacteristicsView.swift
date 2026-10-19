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
            
            Text("Services could not be set up")
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            Text("Connection to the peripheral was successful, but the app was unable to set up its dedicated services.")
                .font(.footnote)
                .padding(.bottom, 32)
                .lineSpacing(10)
            
            Text("Possible reasons")
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            Text("One of the reasons may be an outdated cache. If you installed new firmware on your old peripheral, the old services and characteristics might still be cached on your phone. Try toggling Bluetooth off and on in your phone's settings, then reconnect to the peripheral.")
                .font(.footnote)
                .lineSpacing(10)
                .padding(.bottom, 16)
        }.padding(.vertical, 16)
    }
}

#Preview {
    MissingCharacteristicsView()
}
