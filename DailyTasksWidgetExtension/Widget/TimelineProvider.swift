//
//  TimelineProvider.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/21/26.
//


import WidgetKit
import SwiftUI
import AppIntents

struct TimelineProvider: AppIntentTimelineProvider {
    typealias Entry = TaskEntry
    typealias Intent = DailyTasksIntent
    
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            configuration: DailyTasksIntent(),
            taskData: SharedTaskItem(completedCount: 2, totalCount: 5)
        )
    }
    
    func snapshot(for configuration: DailyTasksIntent, in context: Context) async -> TaskEntry {
        TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())
    }
    
    func timeline(for configuration: DailyTasksIntent, in context: Context) async -> Timeline<TaskEntry> {
        let entry = TaskEntry(date: Date(), configuration: configuration, taskData: fetchSharedData())
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    func recommendations() -> [AppIntentRecommendation<DailyTasksIntent>] {
        return [AppIntentRecommendation(intent: DailyTasksIntent(), description: "Default")]
    }
    
    private func fetchSharedData() -> SharedTaskItem {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
              let savedData = defaults.data(forKey: SharedConstants.tasksKey),
              let decodedData = try? JSONDecoder().decode(SharedTaskItem.self, from: savedData) else {
            return SharedTaskItem(completedCount: 0, totalCount: 0)
        }
        return decodedData
    }
}
