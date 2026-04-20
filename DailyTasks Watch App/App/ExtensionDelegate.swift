//
//  ExtensionDelegate.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/13/26.
//

import WatchKit
import UserNotifications
import SwiftData

class ExtensionDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    
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
                    let container = try ModelContainer(for: DailyTask.self)
                    let context = container.mainContext
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
}
