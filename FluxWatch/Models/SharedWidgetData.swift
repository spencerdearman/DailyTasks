//
//  SharedWidgetData.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - SharedConstants

/// Keys and identifiers shared between the Watch app and its widget extension.
enum SharedConstants {
    static let appGroupIdentifier = "group.com.spencerdearman.Flux"
    static let tasksKey = "widgetTaskData"
}

// MARK: - SharedTaskItem

/// Codable model representing task completion data passed to the widget.
struct SharedTaskItem: Codable {
    var completedCount: Int
    var totalCount: Int
}
