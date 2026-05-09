//
//  CalendarService.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import AppKit
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
    @Published private(set) var googleSignedIn = false
    @Published private(set) var googleUserEmail: String?

    /// All events (today + upcoming) for the agent to reference.
    var allEvents: [CalendarEvent] {
        todayEvents + upcomingEvents
    }

    // MARK: Private

    private let syncService = EventKitSyncService()
    private let googleService = GoogleCalendarService()
    private var refreshTimer: Timer?

    // MARK: Calendar Source Toggles

    var appleCalendarEnabled: Bool {
        UserDefaults.standard.object(forKey: "tetherAppleCalendarEnabled") as? Bool ?? true
    }

    var googleCalendarEnabled: Bool {
        UserDefaults.standard.object(forKey: "tetherGoogleCalendarEnabled") as? Bool ?? true
    }

    // MARK: Public Methods

    /// Fetches events and begins a periodic refresh timer.
    func refresh() {
        fetchEvents()

        if refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Task { @MainActor [weak self] in
                    self?.fetchEvents()
                }
            }
        }
    }

    /// Attempts to restore a previous Google sign-in session.
    func restoreGoogleSignIn() {
        Task {
            let restored = await googleService.restorePreviousSignIn()
            googleSignedIn = restored
            googleUserEmail = googleService.userEmail
            if restored { fetchEvents() }
        }
    }

    /// Signs in to Google Calendar, presenting the sign-in flow in the given window.
    func signInGoogle(presenting window: NSWindow) async throws {
        try await googleService.signIn(presenting: window)
        googleSignedIn = googleService.isSignedIn
        googleUserEmail = googleService.userEmail
        fetchEvents()
    }

    /// Signs out of Google Calendar.
    func signOutGoogle() {
        googleService.signOut()
        googleSignedIn = false
        googleUserEmail = nil
        fetchEvents()
    }

    /// Creates a new calendar event directly (used by the agent).
    func createEvent(title: String, startDate: Date, endDate: Date, location: String?) async throws -> CalendarEvent {
        let granted = try await syncService.requestCalendarAccess()
        guard granted else { throw EventKitSyncError.accessDenied }
        let event = try await syncService.createCalendarEvent(title: title, startDate: startDate, endDate: endDate, location: location)
        fetchEvents()
        return event
    }

    func deleteEvent(withID eventID: String) async throws {
        let granted = try await syncService.requestCalendarAccess()
        guard granted else { throw EventKitSyncError.accessDenied }
        try await syncService.deleteCalendarEvent(withID: eventID)
        fetchEvents()
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
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: .now)
            let weekAhead = calendar.date(byAdding: .day, value: 7, to: start) ?? .now
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? .now
            let now = Date()

            var allToday: [CalendarEvent] = []
            var allUpcoming: [CalendarEvent] = []

            // Apple Calendar
            if appleCalendarEnabled {
                do {
                    let granted = try await syncService.requestCalendarAccess()
                    calendarAccessGranted = granted
                    if granted {
                        allToday += syncService.events(from: start, to: tomorrow)
                            .filter { $0.endDate > now }
                        allUpcoming += syncService.events(from: tomorrow, to: weekAhead)
                    }
                } catch {
                    calendarAccessGranted = false
                }
            }

            // Google Calendar
            print("[CalendarStore] Google enabled=\(googleCalendarEnabled), signedIn=\(googleSignedIn)")
            if googleCalendarEnabled && googleSignedIn {
                do {
                    let googleToday = try await googleService.events(from: start, to: tomorrow)
                        .filter { $0.endDate > now }
                    let googleUpcoming = try await googleService.events(from: tomorrow, to: weekAhead)
                    print("[CalendarStore] Google today: \(googleToday.count), upcoming: \(googleUpcoming.count)")
                    allToday += googleToday
                    allUpcoming += googleUpcoming
                } catch {
                    print("[CalendarStore] Google fetch error: \(error)")
                }
            }

            // Sort by start time and deduplicate by title + start time
            todayEvents = deduplicateAndSort(allToday)
            upcomingEvents = deduplicateAndSort(allUpcoming)
        }
    }

    private func deduplicateAndSort(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events
            .sorted { $0.startDate < $1.startDate }
            .filter { event in
                let key = "\(event.title.lowercased())_\(Int(event.startDate.timeIntervalSince1970))"
                return seen.insert(key).inserted
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
