//
//  NotificationController.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftUI
import UserNotifications
import WatchKit

// MARK: - NotificationController

/// Hosts the custom notification interface for incoming user notifications.
class NotificationController: WKUserNotificationHostingController<NotificationView> {

    // MARK: - Properties

    var titleText: String = "Daily Reminder"
    var bodyText: String = "Check your tasks."

    // MARK: - Body

    override var body: NotificationView {
        return NotificationView(title: titleText, message: bodyText)
    }

    // MARK: - UNNotification Handling

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        titleText = content.title
        bodyText = content.body
    }
}

// MARK: - NotificationView

/// View displayed inside a custom watch notification.
struct NotificationView: View {

    // MARK: - Properties

    var title: String
    var message: String

    // MARK: - Body

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
