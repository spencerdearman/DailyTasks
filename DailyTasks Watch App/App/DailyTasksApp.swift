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
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        
        // 1. Get the App Group URL
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier) else {
            fatalError("Could not get App Group URL. Check your App Group ID in Capabilities.")
        }
        
        // 2. Create the store URL and ensure the directory exists
        let storeURL = groupURL.appendingPathComponent("DailyTasks.sqlite")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            TaskManager.shared.configure(with: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        
        // TODO: If you end up getting rid of the following line,delete NotificationController as well.
//        WKNotificationScene(controller: NotificationController.self, category: "dailyReminderCategory")
    }
}
