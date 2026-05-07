//
//  FluxWidget.swift
//  FluxWidgetExtension
//
//  Created by Spencer Dearman.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Definition

/// The primary Flux widget that displays daily task progress on the watch face.
struct FluxWidget: Widget {
    let kind: String = "FluxWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FluxIntent.self, provider: TimelineProvider()) { entry in
            FluxWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Flux")
        .description("Keep track of your daily task progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
