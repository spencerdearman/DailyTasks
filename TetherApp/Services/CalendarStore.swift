//
//  CalendarStore.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Combine
import Foundation
import UIKit

// MARK: - CalendarStore

/// Manages calendar event data and provides reactive access to today's and upcoming events.
@MainActor
final class CalendarStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var calendarAccessGranted = false
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

    /// Signs in to Google Calendar from the given view controller.
    func signInGoogle(presenting viewController: UIViewController) async throws {
        try await googleService.signIn(presenting: viewController)
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
            if googleCalendarEnabled && googleSignedIn {
                do {
                    let googleToday = try await googleService.events(from: start, to: tomorrow)
                        .filter { $0.endDate > now }
                    let googleUpcoming = try await googleService.events(from: tomorrow, to: weekAhead)
                    allToday += googleToday
                    allUpcoming += googleUpcoming
                } catch {
                    // Google fetch failed — continue with Apple events only
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
