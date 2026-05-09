//
//  PopoverBackgroundCleaner.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

extension View {
    /// Applies a solid dark background that matches the app theme,
    /// covering the default macOS popover material background.
    func popoverBackgroundClean() -> some View {
        self.background {
            Color(white: 0.1)
                .ignoresSafeArea()
        }
    }
}
