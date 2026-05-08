//
//  TetherIntent.swift
//  TetherWidgetExtension
//
//  Created by Spencer Dearman.
//

import AppIntents
import WidgetKit

// MARK: - Widget Intent

/// Configuration intent for the Tether widget, allowing the user to select which task data to display.
struct TetherIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Tasks"
    static var description = IntentDescription("Select which task data to display.")

    public init() {}
}
