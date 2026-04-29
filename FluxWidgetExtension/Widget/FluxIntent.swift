//
//  FluxIntent.swift
//  Flux
//
//  Created by Spencer Dearman.
//


import WidgetKit
import SwiftUI
import AppIntents

struct FluxIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Tasks"
    static var description = IntentDescription("Select which task data to display.")
    public init() {}
}
