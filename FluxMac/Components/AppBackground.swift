//
//  AppBackground.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - AppBackground

/// A subtle gradient background that adapts to the current color scheme.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.11), Color(white: 0.09)]
                : [Color.white, Color(white: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
