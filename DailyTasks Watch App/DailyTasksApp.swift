//
//  DailyTasksApp.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI
import SwiftData

@main
struct DailyTasks_Watch_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyTask.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
