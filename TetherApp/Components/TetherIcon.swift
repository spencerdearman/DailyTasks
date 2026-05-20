//
//  TetherIcon.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

/// A reusable Tether icon view that renders the custom "tether" asset
/// at a given point size, matching SF Symbol sizing conventions.
struct TetherIcon: View {
    let size: CGFloat

    init(size: CGFloat = 16) {
        self.size = size
    }

    var body: some View {
        Image("tether")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
