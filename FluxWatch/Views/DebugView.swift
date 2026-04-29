//
//  DebugView.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI

extension Notification.Name {
    static let testNotification = Notification.Name("debug.testNotification")
    static let testWalkSimulation = Notification.Name("debug.testWalkSimulation")
    static let testMidnightReset = Notification.Name("debug.testMidnightReset")
}

#if DEBUG
import SwiftData
struct DebugView: View {
    @Query(sort: \DailyTask.createdAt, order: .reverse) private var tasks: [DailyTask]
    @AppStorage("lastResetDate") private var lastResetDateInterval: TimeInterval = 0
    var walkManager = WalkDetectionManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("Smart Reminders") {
                    Button("5s Test Notification") {
                        UNUserNotificationCenter
                            .current()
                            .requestAuthorization(options: [.alert, .sound, .badge]) {
                                granted,
                                _ in
                                guard granted else { return }
                                
                                let remaining = tasks.filter { !$0.isCompleted }.count
                                let content = UNMutableNotificationContent()
                                content.title = "Test Reminder 🛠️"
                                content.body = "You have \(remaining) tasks left. (TEST)"
                                content.sound = .default
                                
                                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                                let request = UNNotificationRequest(
                                    identifier: "debug_reminder",
                                    content: content,
                                    trigger: trigger
                                )
                                
                                UNUserNotificationCenter.current().add(request)
                            }
                    }
                }
                
                Section {
                    Button("Simulate Walk") {
                        walkManager.simulateWalkDetected()
                    }
                } header: {
                    Text("Walk Detection")
                } footer: {
                    Text("Switch to Tasks tab to see dialog.")
                }
                
                
                Section("Lifecycle") {
                    Button("Midnight Reset") {
                        lastResetDateInterval = Date().addingTimeInterval(-86400 * 2).timeIntervalSince1970
                        NotificationCenter.default.post(name: .testMidnightReset, object: nil)
                    }
                }
            }
            .navigationTitle("Debug")
        }
    }
}
#endif
