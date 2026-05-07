//
//  TaskItem+Extensions.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Computed Properties

extension TaskItem {

    /// The resolved task status derived from the raw string value.
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    /// Whether this task has been marked as completed.
    var isCompleted: Bool {
        status == .completed
    }

    /// The most relevant date for scheduling purposes (when date or deadline).
    var effectiveDate: Date? {
        whenDate ?? deadline
    }

    /// Whether this task has an associated calendar event.
    var hasCalendarEvent: Bool {
        calendarEventID?.isEmpty == false
    }

    /// The recommended start time for calendar scheduling.
    var suggestedCalendarStartAt: Date {
        let calendar = Calendar.current

        if let calendarStartAt {
            return calendarStartAt
        }

        if let deadline {
            let components = calendar.dateComponents([.hour, .minute], from: deadline)
            if components.hour != 0 || components.minute != 0 {
                return deadline
            }
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: deadline) ?? deadline
        }

        if let whenDate {
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: whenDate) ?? whenDate
        }

        let now = Date()
        let nextHour = calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
        return nextHour
    }

    /// Whether the deadline includes an explicit time component.
    var hasExplicitDeadlineTime: Bool {
        guard let deadline else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: deadline)
        return components.hour != 0 || components.minute != 0
    }

    /// Whether the calendar start time includes an explicit time component.
    var hasExplicitCalendarStartTime: Bool {
        guard let calendarStartAt else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: calendarStartAt)
        return components.hour != 0 || components.minute != 0
    }

    /// All tags assigned to this task.
    var tagList: [Tag] {
        tagAssignments?.compactMap(\.tag) ?? []
    }

    /// All tag assignments for this task.
    var tagAssignmentList: [TaskTagAssignment] {
        tagAssignments ?? []
    }

    /// All checklist items belonging to this task.
    var checklistItems: [ChecklistItem] {
        checklist ?? []
    }

    /// A concatenated plain-text representation of task metadata for search.
    var plainContext: String {
        [title, notes, area?.title, project?.title, tagList.map(\.title).joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// A human-readable description of the recurrence rule.
    var recurrenceDescription: String? {
        guard let rule = recurrenceRule else { return nil }
        switch rule {
        case "daily": return "Every day"
        case "weekly": return "Every week"
        case "biweekly": return "Every 2 weeks"
        case "monthly": return "Every month"
        case "yearly": return "Every year"
        default: return rule
        }
    }
}

// MARK: - Actions

extension TaskItem {

    /// Marks the task as completed with the current timestamp.
    func markComplete() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    /// Reopens a completed task, clearing the completion timestamp.
    func reopen() {
        status = .active
        completedAt = nil
        updatedAt = Date()
    }
}
