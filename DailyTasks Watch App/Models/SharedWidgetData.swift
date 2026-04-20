//
//  SharedWidgetData.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/13/26.
//

// NOTE: Target membership is DailyTasks Watch App + Widget Extension

import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.spencerdearman.DailyTasks"
    static let tasksKey = "widgetTaskData"
}

struct SharedTaskItem: Codable {
    var completedCount: Int
    var totalCount: Int
}
