//
//  CalendarEvent.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - CalendarEvent

/// A lightweight representation of an EventKit calendar event used throughout the app.
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}
