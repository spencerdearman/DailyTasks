//
//  WidgetDataManager.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import Foundation
import WidgetKit

// MARK: - WidgetDataManager

/// Manages encoding and pushing task data to the shared app group for widget consumption.
struct WidgetDataManager {

    // MARK: - Properties

    static let shared = WidgetDataManager()

    // MARK: - Methods

    /// Encodes the current task counts and triggers a widget timeline reload.
    func updateWidgetData(completed: Int, total: Int) {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else { return }

        let data = SharedTaskItem(completedCount: completed, totalCount: total)
        if let encodedData = try? JSONEncoder().encode(data) {
            defaults.set(encodedData, forKey: SharedConstants.tasksKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
