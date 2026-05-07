//
//  TaskEntry.swift
//  FluxWidgetExtension
//
//  Created by Spencer Dearman.
//

import WidgetKit

// MARK: - Timeline Entry

/// A single point-in-time snapshot of task data used by the widget timeline.
struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: FluxIntent
    let taskData: SharedTaskItem
}
