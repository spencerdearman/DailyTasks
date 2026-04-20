//
//  WidgetDataManager.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman on 4/13/26.
//
//  NOTE: Lives in the Watch App target. Writes shared task data to the
//  App Group UserDefaults that the widget timeline provider reads from,
//  then asks WidgetKit to reload timelines.

import Foundation
import WidgetKit

struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    func updateWidgetData(completed: Int, total: Int) {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else { return }
        
        let data = SharedTaskItem(completedCount: completed, totalCount: total)
        if let encodedData = try? JSONEncoder().encode(data) {
            defaults.set(encodedData, forKey: SharedConstants.tasksKey)
            // Force timeline refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
