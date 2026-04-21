//
//  DailyTasksWidget.swift
//  DailyTasksWidgetExtension
//
//  Created by Spencer Dearman.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: Widget
struct DailyTasksWidget: Widget {
    let kind: String = "DailyTasksWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DailyTasksIntent.self, provider: TimelineProvider()) { entry in
            DailyTasksWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Tasks Tracker")
        .description("Keep track of your daily task progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
