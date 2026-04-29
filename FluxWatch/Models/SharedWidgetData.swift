//
//  SharedWidgetData.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.spencerdearman.Flux"
    static let tasksKey = "widgetTaskData"
}

struct SharedTaskItem: Codable {
    var completedCount: Int
    var totalCount: Int
}

