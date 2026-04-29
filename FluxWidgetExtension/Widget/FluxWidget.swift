//
//  FluxWidget.swift
//  FluxWidgetExtension
//
//  Created by Spencer Dearman.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: Widget
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
