import Foundation
import UserNotifications

struct SmartReminderManager {
    static func scheduleSmartReminder(total: Int, remaining: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "smart_reminder"
        
        // Cancel existing smart reminders before scheduling new ones
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // All done → cancel (which we just did)
        if remaining <= 0 || total == 0 {
            return
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        let timeInterval: TimeInterval
        let title: String
        let body: String
        
        if hour >= 23 {
            // At 11 PM+ -> 30-minute urgent nudge
            timeInterval = 1800 // 30 minutes
            title = "Final Countdown! ⏰"
            body = "You have \(remaining) task\(remaining > 1 ? "s" : "") left for the day. Let's finish strong!"
        } else {
            // Before 11 PM -> 1-hour progress nudge
            timeInterval = 3600 // 1 hour
            let completed = total - remaining
            if completed == 0 {
                title = "Start Your Day! ☀️"
                body = "You have \(total) task\(total > 1 ? "s" : "") to complete today."
            } else {
                title = "Keep Your Streak Alive! 🔥"
                body = "Only \(remaining) task\(remaining > 1 ? "s" : "") remaining. You've got this!"
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Relative scheduling
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}
