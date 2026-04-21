//
//  DailyTasksMacApp.swift
//  DailyTasksMac
//
//  Created by Spencer Dearman on 4/20/26.
//

import SwiftUI
import SwiftData

@main
struct DailyTasksMacApp: App {
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        
        // Let SwiftData dynamically construct the default secure Mac Sandbox footprint locally
        // while cleanly leaning onto remote CloudKit syncing to bridge the database!
        let modelConfiguration = ModelConfiguration("DailyTasks", schema: schema, cloudKitDatabase: .automatic)

        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra("DailyTasks", systemImage: "checkmark.circle") {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
