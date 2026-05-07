//
//  FluxWidgetExtensionBundle.swift
//  FluxWidgetExtension
//
//  Created by Spencer Dearman.
//

import SwiftUI
import WidgetKit

// MARK: - Widget Bundle

/// The main entry point for the Flux widget extension, declaring all available widgets.
@main
struct FluxWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        FluxWidget()
    }
}
