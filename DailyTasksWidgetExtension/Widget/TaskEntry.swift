//
//  TaskEntry.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/21/26.
//


import WidgetKit
import SwiftUI
import AppIntents

struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: DailyTasksIntent
    let taskData: SharedTaskItem
}
