//
//  ReminderView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftUI
import UserNotifications

// MARK: - ReminderView

/// Allows the user to configure smart and daily reminder notifications.
struct ReminderView: View {

    // MARK: - Properties

    @AppStorage("smartRemindersEnabled") var smartRemindersEnabled: Bool = false
    @AppStorage("dailyRemindersEnabled") var dailyRemindersEnabled: Bool = false
    @AppStorage("selectedTimeInterval") private var selectedTimeInterval: TimeInterval = Date.now.timeIntervalSince1970

    private var selectedTime: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: selectedTimeInterval) },
            set: { selectedTimeInterval = $0.timeIntervalSince1970 }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $smartRemindersEnabled) {
                        Text("Smart Reminders")
                    }
                    .tint(.accentColor)
                } footer: {
                    Text("Get nudged when you still have tasks left after checking one off.")
                }

                Section {
                    Toggle(isOn: $dailyRemindersEnabled) {
                        Text("Daily Reminders")
                    }
                    .tint(.accentColor)
                    .onChange(of: dailyRemindersEnabled) { _, isEnabled in
                        if isEnabled {
                            scheduleDailyReminder(for: selectedTime.wrappedValue)
                        } else {
                            cancelDailyReminder()
                        }
                    }

                    if dailyRemindersEnabled {
                        NavigationLink {
                            DatePicker(
                                "Time",
                                selection: selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .navigationTitle("Time")
                            .tint(.orange)
                            .onChange(of: selectedTime.wrappedValue) { _, newTime in
                                scheduleDailyReminder(for: newTime)
                            }
                        } label: {
                            HStack {
                                Text("Select Time")
                                Spacer()
                                Text(selectedTime.wrappedValue, style: .time)
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
        }
    }

    // MARK: - Private Methods

    /// Schedules a repeating daily notification at the given time.
    private func scheduleDailyReminder(for date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Flux"
        content.body = "You have tasks waiting to be completed."
        content.categoryIdentifier = "dailyReminderCategory"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    /// Cancels all pending daily reminder notifications.
    private func cancelDailyReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
