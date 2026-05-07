//
//  CalendarService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Combine
import EventKit
import Foundation
import SwiftData

// MARK: - CalendarEvent

/// A value type representing a single calendar event for display purposes.
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

// MARK: - CalendarStore

/// Manages calendar event data and provides reactive access to today's and upcoming events.
@MainActor
final class CalendarStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var calendarAccessGranted = false
    @Published private(set) var remindersAccessGranted = false

    /// All events (today + upcoming) for the agent to reference.
    var allEvents: [CalendarEvent] {
        todayEvents + upcomingEvents
    }

    // MARK: Private

    private let syncService = EventKitSyncService()
    private var refreshTimer: Timer?

    // MARK: Public Methods

    /// Fetches events and begins a periodic refresh timer.
    func refresh() {
        fetchEvents()

        if refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                Task { @MainActor [weak self] in
                    self?.fetchEvents()
                }
            }
        }
    }

    /// Creates a new calendar event directly (used by the agent).
    func createEvent(title: String, startDate: Date, endDate: Date, location: String?) async throws -> CalendarEvent {
        let granted = try await syncService.requestCalendarAccess()
        guard granted else { throw EventKitSyncError.accessDenied }
        let event = try await syncService.createCalendarEvent(title: title, startDate: startDate, endDate: endDate, location: location)
        fetchEvents()
        return event
    }

    /// Imports incomplete reminders from EventKit into the SwiftData store.
    func importReminders(into context: ModelContext, areas: [Area]) {
        Task {
            do {
                let granted = try await syncService.requestRemindersAccess()
                remindersAccessGranted = granted
                guard granted else { return }

                let reminders = try await syncService.incompleteReminders()
                let existingTitles = Set(
                    (try? context.fetch(FetchDescriptor<TaskItem>()))?.map { $0.title.lowercased() } ?? []
                )

                for reminder in reminders where !existingTitles.contains(reminder.title.lowercased()) {
                    let notes = reminder.notes ?? ""
                    let decision = SemanticRouter.analyze(title: reminder.title, notes: notes, areas: areas)
                    let task = TaskItem(
                        title: reminder.title,
                        notes: notes,
                        whenDate: reminder.dueDateComponents?.date,
                        deadline: reminder.dueDateComponents?.date,
                        status: decision.suggestedStatus,
                        isInInbox: decision.matchedArea == nil,
                        isEvening: decision.shouldMarkEvening,
                        area: decision.matchedArea
                    )
                    context.insert(task)
                }

                try? context.save()
            } catch {
                remindersAccessGranted = false
            }
        }
    }

    // MARK: Private Methods

    private func fetchEvents() {
        Task {
            do {
                let granted = try await syncService.requestCalendarAccess()
                calendarAccessGranted = granted

                guard granted else {
                    todayEvents = []
                    upcomingEvents = []
                    return
                }

                let calendar = Calendar.current
                let start = calendar.startOfDay(for: .now)
                let weekAhead = calendar.date(byAdding: .day, value: 7, to: start) ?? .now
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? .now

                let now = Date()
                todayEvents = syncService.events(from: start, to: tomorrow)
                    .filter { $0.endDate > now }
                upcomingEvents = syncService.events(from: tomorrow, to: weekAhead)
            } catch {
                calendarAccessGranted = false
                todayEvents = []
                upcomingEvents = []
            }
        }
    }
}

// MARK: - CalendarEvent + EKEvent

private extension CalendarEvent {
    init(event: EKEvent) {
        self.id = event.eventIdentifier
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.isAllDay = event.isAllDay
    }
}
