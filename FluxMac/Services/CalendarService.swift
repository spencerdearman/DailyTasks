//
//  FluxMacCalendarService.swift
//  FluxMac
//
//  Created by OpenAI.
//

import Combine
import EventKit
import Foundation
import SwiftData

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var todayEvents: [CalendarEvent] = []
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var calendarAccessGranted = false
    @Published private(set) var remindersAccessGranted = false
    
    private let syncService = EventKitSyncService()
    
    func refresh() {
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
                
                todayEvents = syncService.events(from: start, to: tomorrow)
                upcomingEvents = syncService.events(from: tomorrow, to: weekAhead)
            } catch {
                calendarAccessGranted = false
                todayEvents = []
                upcomingEvents = []
            }
        }
    }
    
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
}

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
