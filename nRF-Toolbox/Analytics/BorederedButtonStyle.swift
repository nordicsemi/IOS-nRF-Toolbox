//
//  BorederedButtonStyle.swift
//  nRF Toolbox
//
//  Created by Sylwester Zielinski on 07/08/2026.
//  Copyright © 2026 Nordic Semiconductor. All rights reserved.
//

import SwiftUI

struct BorederedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 36)
                .fill(Color(uiColor: .secondarySystemBackground))
            )
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
