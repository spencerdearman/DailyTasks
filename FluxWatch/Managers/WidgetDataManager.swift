//
//  WidgetDataManager.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import Foundation
import WidgetKit

struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    func updateWidgetData(completed: Int, total: Int) {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else { return }
        
        let data = SharedTaskItem(completedCount: completed, totalCount: total)
        if let encodedData = try? JSONEncoder().encode(data) {
            defaults.set(encodedData, forKey: SharedConstants.tasksKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
