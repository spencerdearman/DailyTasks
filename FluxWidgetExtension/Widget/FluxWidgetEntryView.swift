//
//  FluxWidgetEntryView.swift
//  Flux
//
//  Created by Spencer Dearman on 4/21/26.
//


import WidgetKit
import SwiftUI
import AppIntents

struct FluxWidgetEntryView: View {
    var entry: TimelineProvider.Entry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        let completed = Double(entry.taskData.completedCount)
        let total = Double(max(entry.taskData.totalCount, 1))
        let left = max(0, entry.taskData.totalCount - entry.taskData.completedCount)
        
        switch family {
        case .accessoryCircular:
            Gauge(value: completed, in: 0...total) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(entry.taskData.completedCount)")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(.accentColor)
            
        case .accessoryRectangular:
            HStack {
                VStack(alignment: .leading) {
                    Text("Tasks").font(.headline)
                    Text("\(entry.taskData.completedCount) of \(entry.taskData.totalCount)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Gauge(value: completed, in: 0...total) {
                    Text("")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.accentColor)
            }
            
        case .accessoryInline:
            Text("\(Image(systemName: "checkmark.circle")) \(entry.taskData.completedCount)/\(entry.taskData.totalCount) TASKS • \(left) LEFT")
            
        case .accessoryCorner:
            Text("\(left) LEFT")
                .widgetCurvesContent()
                .widgetLabel {
                    ProgressView(value: completed, total: total)
                        .tint(.accentColor)
                }
            
        default:
            Text("Unsupported")
        }
    }
}
