//
//  DailyTasksIntent.swift
//  DailyTasks
//
//  Created by Spencer Dearman.
//


import WidgetKit
import SwiftUI
import AppIntents

struct DailyTasksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Tasks"
    static var description = IntentDescription("Select which task data to display.")
    public init() {}
}
