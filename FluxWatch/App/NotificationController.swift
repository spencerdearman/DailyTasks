//
//  NotificationController.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import WatchKit
import SwiftUI
import UserNotifications

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    var titleText: String = "Daily Reminder"
    var bodyText: String = "Check your tasks."
    
    override var body: NotificationView {
        return NotificationView(title: titleText, message: bodyText)
    }
    
    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        titleText = content.title
        bodyText = content.body
    }
}

struct NotificationView: View {
    var title: String
    var message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
