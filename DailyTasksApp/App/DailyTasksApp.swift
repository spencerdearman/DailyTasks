//
//  DailyTasksApp.swift
//  DailyTasksApp
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

@main
struct DailyTasksApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.DailyTasks"
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        let modelConfiguration = ModelConfiguration(
            "DailyTasks",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        
        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
