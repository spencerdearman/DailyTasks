import EventKit
import Foundation

enum EventKitSyncError: LocalizedError {
    case accessDenied
    case missingDefaultCalendar
    case missingDefaultReminderList

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Flux does not have access to your calendar or reminders."
        case .missingDefaultCalendar:
            return "No default calendar is available for new events."
        case .missingDefaultReminderList:
            return "No default reminders list is available."
        }
    }
}

@MainActor
final class EventKitSyncService {
    private let eventStore = EKEventStore()

    func requestCalendarAccess() async throws -> Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess:
                return true
            case .writeOnly, .notDetermined:
                return try await eventStore.requestFullAccessToEvents()
            case .denied, .restricted:
                return false
            @unknown default:
                return false
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .authorized, .fullAccess:
                return true
            case .writeOnly:
                return false
            case .notDetermined:
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            case .denied, .restricted:
                return false
            @unknown default:
                return false
            }
        }
    }

    func requestRemindersAccess() async throws -> Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            switch EKEventStore.authorizationStatus(for: .reminder) {
            case .fullAccess:
                return true
            case .writeOnly, .notDetermined:
                return try await eventStore.requestFullAccessToReminders()
            case .denied, .restricted:
                return false
            @unknown default:
                return false
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .reminder) {
            case .authorized, .fullAccess:
                return true
            case .writeOnly:
                return false
            case .notDetermined:
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            case .denied, .restricted:
                return false
            @unknown default:
                return false
            }
        }
    }

    func events(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEvent(
                    id: $0.eventIdentifier,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    location: $0.location,
                    isAllDay: $0.isAllDay
                )
            }
    }

    func incompleteReminders() async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func upsertCalendarEvent(for task: TaskItem) async throws {
        guard try await requestCalendarAccess() else {
            throw EventKitSyncError.accessDenied
        }

        let event: EKEvent
        if let eventID = task.calendarEventID, let existingEvent = eventStore.event(withIdentifier: eventID) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
            guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
                throw EventKitSyncError.missingDefaultCalendar
            }
            event.calendar = defaultCalendar
        }

        let startDate = task.suggestedCalendarStartAt
        let durationMinutes = max(task.calendarDurationMinutes, 15)

        event.title = task.title
        event.notes = task.notes.isEmpty ? nil : task.notes
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.isAllDay = false

        try eventStore.save(event, span: .thisEvent)

        task.calendarEventID = event.eventIdentifier
        task.calendarStartAt = startDate
        task.calendarDurationMinutes = durationMinutes
        task.whenDate = Calendar.current.startOfDay(for: startDate)
        task.status = .active
        task.updatedAt = Date()
    }

    func removeCalendarEvent(for task: TaskItem) async throws {
        guard try await requestCalendarAccess() else {
            throw EventKitSyncError.accessDenied
        }

        if let eventID = task.calendarEventID, let event = eventStore.event(withIdentifier: eventID) {
            try eventStore.remove(event, span: .thisEvent)
        }

        task.calendarEventID = nil
        task.calendarStartAt = nil
        task.updatedAt = Date()
    }

    func upsertReminder(for task: TaskItem) async throws {
        guard try await requestRemindersAccess() else {
            throw EventKitSyncError.accessDenied
        }

        let reminder = EKReminder(eventStore: eventStore)
        guard let defaultCalendar = eventStore.defaultCalendarForNewReminders() else {
            throw EventKitSyncError.missingDefaultReminderList
        }

        reminder.calendar = defaultCalendar
        reminder.title = task.title
        reminder.notes = task.notes.isEmpty ? nil : task.notes
        if let deadline = task.deadline {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: deadline
            )
        }

        try eventStore.save(reminder, commit: true)
        task.reminderItemID = reminder.calendarItemIdentifier
        task.updatedAt = Date()
    }
}
