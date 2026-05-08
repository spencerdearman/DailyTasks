//
//  TetherWidgetExtensionBundle.swift
//  TetherWidgetExtension
//
//  Created by Spencer Dearman.
//

import SwiftUI
import WidgetKit

// MARK: - Widget Bundle

/// The main entry point for the Tether widget extension, declaring all available widgets.
@main
struct TetherWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TetherWidget()
    }
}
