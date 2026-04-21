//
//  SmartReminderManager.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import Foundation
import UserNotifications

struct SmartReminderManager {
    static func scheduleSmartReminder(total: Int, remaining: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "smart_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        if remaining <= 0 || total == 0 {
            return // No tasks remaining, no reminder needed.
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Tasks"
        if remaining == 1 {
            content.body = "You're nearly done! Only 1 task left to complete today."
        } else {
            content.body = "You have \(remaining) tasks left to complete today. Keep your streak alive!"
        }
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        
        // Schedule for 8 PM natively
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 20 // 8 PM
        dateComponents.minute = 0
        
        // If it's already past 8 PM, schedule strictly for tomorrow 8 PM
        if let targetDate = Calendar.current.date(from: dateComponents), targetDate <= Date() {
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                dateComponents.hour = 20
                dateComponents.minute = 0
            }
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling smart reminder: \(error.localizedDescription)")
            }
        }
    }
}
