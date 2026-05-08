//
//  SharedWidgetData.swift
//  TetherWatch
//
//  Created by Spencer Dearman.
//

import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.spencerdearman.Tether"
    static let tasksKey = "widgetTaskData"
}

struct SharedTaskItem: Codable {
    var completedCount: Int
    var totalCount: Int
}
