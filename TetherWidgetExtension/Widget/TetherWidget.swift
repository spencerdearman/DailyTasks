//
//  TetherWidget.swift
//  TetherWidgetExtension
//
//  Created by Spencer Dearman.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Definition

/// The primary Tether widget that displays daily task progress on the watch face.
struct TetherWidget: Widget {
    let kind: String = "TetherWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TetherIntent.self, provider: TimelineProvider()) { entry in
            TetherWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tether")
        .description("Keep track of your daily task progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
