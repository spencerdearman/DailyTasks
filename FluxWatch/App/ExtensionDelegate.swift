//
//  ExtensionDelegate.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import UserNotifications
import WatchKit

// MARK: - ExtensionDelegate

/// Handles application lifecycle events and notification actions for the Watch extension.
class ExtensionDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Properties

    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Flux"

    // MARK: - WKApplicationDelegate

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

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "markAllDone" {
            Task { @MainActor in
                do {
                    let context = try makeModelContext()
                    let today = Calendar.current.startOfDay(for: .now)
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

                    var descriptor = FetchDescriptor<TaskItem>(
                        predicate: #Predicate<TaskItem> { task in
                            task.statusRaw == "active" &&
                            task.whenDate != nil &&
                            task.whenDate! >= today &&
                            task.whenDate! < tomorrow
                        }
                    )
                    let tasks = try context.fetch(descriptor)

                    for task in tasks {
                        task.markComplete()
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

    // MARK: - Private Methods

    /// Creates or retrieves a `ModelContext` for persisting task data.
    @MainActor
    private func makeModelContext() throws -> ModelContext {
        if let container = TaskManager.shared.modelContainer {
            return container.mainContext
        }

        let schema = Schema([
            Area.self,
            Project.self,
            Heading.self,
            TaskItem.self,
            ChecklistItem.self,
            Tag.self,
            TaskTagAssignment.self
        ])
        let configuration = ModelConfiguration(
            "Flux",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        TaskManager.shared.configure(with: container)
        return container.mainContext
    }
}
