//
//  TaskEntry.swift
//  TetherWidgetExtension
//
//  Created by Spencer Dearman.
//

import WidgetKit

// MARK: - Timeline Entry

/// A single point-in-time snapshot of task data used by the widget timeline.
struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: TetherIntent
    let taskData: SharedTaskItem
}
