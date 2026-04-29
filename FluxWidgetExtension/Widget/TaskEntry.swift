//
//  TaskEntry.swift
//  Flux
//
//  Created by Spencer Dearman on 4/21/26.
//


import WidgetKit
import SwiftUI
import AppIntents

struct TaskEntry: TimelineEntry {
    let date: Date
    let configuration: FluxIntent
    let taskData: SharedTaskItem
}
