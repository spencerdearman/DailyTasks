//
//  CalendarStore.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Combine
import Foundation

// MARK: - CalendarStore

/// Manages calendar event data and provides reactive access to today's and upcoming events.
@MainActor
final class CalendarStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var calendarAccessGranted = false

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
