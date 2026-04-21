//
//  ExtensionDelegate.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import WatchKit
import UserNotifications
import SwiftData

class ExtensionDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.DailyTasks"
    
    func applicationDidFinishLaunching() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Authorization error: \(error.localizedDescription)")
            }
        }
        
        let markDoneAction = UNNotificationAction(
            identifier: "markAllDone",
            title: "Mark All Done",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "dailyReminderCategory",
            actions: [markDoneAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "markAllDone" {
            Task { @MainActor in
                do {
                    let context = try makeModelContext()
                    let tasks = try context.fetch(FetchDescriptor<DailyTask>())
                    
                    for task in tasks {
                        if !task.isCompleted {
                            task.isCompleted = true
                            task.streak += 1
                        }
                    }
                    try context.save()
                } catch {
                    print("Failed to process action: \(error)")
                }
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    @MainActor
    private func makeModelContext() throws -> ModelContext {
        if let container = TaskManager.shared.modelContainer {
            return container.mainContext
        }
        
        let schema = Schema([DailyTask.self])
        let configuration = ModelConfiguration(
            "DailyTasks",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        TaskManager.shared.configure(with: container)
        return container.mainContext
    }
}
