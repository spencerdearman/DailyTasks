//
//  GoogleCalendarService.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Foundation
import GoogleSignIn
import UIKit

// MARK: - GoogleCalendarService

/// Manages Google Calendar authentication and event fetching via the Google Calendar REST API.
@MainActor
final class GoogleCalendarService {

    // MARK: State

    private(set) var isSignedIn = false
    private(set) var userEmail: String?

    // MARK: - Auth

    /// Presents the Google Sign-In flow from the given view controller.
    func signIn(presenting viewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"]
        )
        isSignedIn = true
        userEmail = result.user.profile?.email
    }

    /// Signs out and clears state.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
    }

    /// Restores a previous sign-in session if available.
    func restorePreviousSignIn() async -> Bool {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let scopes = user.grantedScopes ?? []
            guard scopes.contains("https://www.googleapis.com/auth/calendar.readonly") else {
                return false
            }
            isSignedIn = true
            userEmail = user.profile?.email
            return true
        } catch {
            isSignedIn = false
            userEmail = nil
            return false
        }
    }

    // MARK: - Events

    /// Fetches calendar events in the given date range from all Google Calendars.
    func events(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            return []
        }

        try await user.refreshTokensIfNeeded()

        guard let accessToken = user.accessToken.tokenString as String? else {
            return []
        }

        let calendarIDs = try await fetchCalendarIDs(accessToken: accessToken)

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        var allEvents: [CalendarEvent] = []

        for calendarID in calendarIDs {
            guard let encodedID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }

            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedID)/events")!
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: timeMin),
                URLQueryItem(name: "timeMax", value: timeMax),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "50"),
            ]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                continue
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let items = json?["items"] as? [[String: Any]] {
                allEvents += items.compactMap { parseEvent($0) }
            }
        }

        return allEvents
    }

    /// Fetches all calendar IDs the user has access to.
    private func fetchCalendarIDs(accessToken: String) async throws -> [String] {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return ["primary"]
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let items = json?["items"] as? [[String: Any]] else {
            return ["primary"]
        }

        return items.compactMap { $0["id"] as? String }
    }

    // MARK: - Private

    private func parseEvent(_ dict: [String: Any]) -> CalendarEvent? {
        guard let id = dict["id"] as? String,
              let summary = dict["summary"] as? String else {
            return nil
        }

        let startDict = dict["start"] as? [String: Any]
        let endDict = dict["end"] as? [String: Any]

        let isAllDay = startDict?["date"] != nil
        let startDate: Date
        let endDate: Date

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"

        if isAllDay {
            guard let startStr = startDict?["date"] as? String,
                  let endStr = endDict?["date"] as? String,
                  let s = dateOnly.date(from: startStr),
                  let e = dateOnly.date(from: endStr) else { return nil }
            startDate = s
            endDate = e
        } else {
            guard let startStr = startDict?["dateTime"] as? String,
                  let endStr = endDict?["dateTime"] as? String else { return nil }
            guard let s = isoFormatter.date(from: startStr) ?? isoBasic.date(from: startStr),
                  let e = isoFormatter.date(from: endStr) ?? isoBasic.date(from: endStr) else { return nil }
            startDate = s
            endDate = e
        }

        let location = dict["location"] as? String

        return CalendarEvent(
            id: "google_\(id)",
            title: summary,
            startDate: startDate,
            endDate: endDate,
            location: location,
            isAllDay: isAllDay
        )
    }
}
