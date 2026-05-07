//
//  TimelineProvider.swift
//  FluxWidgetExtension
//
//  Created by Spencer Dearman.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

/// Supplies timeline entries to the widget by reading shared task data from the app group.
struct TimelineProvider: AppIntentTimelineProvider {
    typealias Entry = TaskEntry
    typealias Intent = FluxIntent

    // MARK: - AppIntentTimelineProvider

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            configuration: FluxIntent(),
            taskData: SharedTaskItem(completedCount: 2, totalCount: 5)
        )
    }

    func snapshot(for configuration: FluxIntent, in context: Context) async -> TaskEntry {
        TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())
    }

    func timeline(for configuration: FluxIntent, in context: Context) async -> Timeline<TaskEntry> {
        let entry = TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<FluxIntent>] {
        return [AppIntentRecommendation(intent: FluxIntent(), description: "Default")]
    }

    // MARK: - Private Helpers

    /// Reads the latest task data from the shared `UserDefaults` suite.
    private func fetchSharedData() -> SharedTaskItem {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
              let savedData = defaults.data(forKey: SharedConstants.tasksKey),
              let decodedData = try? JSONDecoder().decode(SharedTaskItem.self, from: savedData) else {
            return SharedTaskItem(completedCount: 0, totalCount: 0)
        }
        return decodedData
    }
}
