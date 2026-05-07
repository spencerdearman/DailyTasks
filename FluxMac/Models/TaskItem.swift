//
//  TaskItem.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - TaskItem

/// The core data model representing a single actionable task.
@Model
final class TaskItem {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var whenDate: Date?
    var deadline: Date?
    var completedAt: Date?
    var statusRaw: String = TaskStatus.active.rawValue
    var isInInbox: Bool = true
    var isEvening: Bool = false
    var calendarEventID: String?
    var calendarStartAt: Date?
    var calendarDurationMinutes: Int = 60
    var reminderItemID: String?
    var sortOrder: Double = 0
    var recurrenceRule: String?
    var locationName: String?
    var locationLatitude: Double?
    var locationLongitude: Double?

    // MARK: Relationships

    var area: Area?
    var project: Project?
    var heading: Heading?

    @Relationship(deleteRule: .cascade, inverse: \TaskTagAssignment.task)
    var tagAssignments: [TaskTagAssignment]?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.task)
    var checklist: [ChecklistItem]?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        whenDate: Date? = nil,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        status: TaskStatus = .active,
        isInInbox: Bool = true,
        isEvening: Bool = false,
        calendarEventID: String? = nil,
        calendarStartAt: Date? = nil,
        calendarDurationMinutes: Int = 60,
        reminderItemID: String? = nil,
        sortOrder: Double = 0,
        recurrenceRule: String? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        area: Area? = nil,
        project: Project? = nil,
        heading: Heading? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.whenDate = whenDate
        self.deadline = deadline
        self.completedAt = completedAt
        self.statusRaw = status.rawValue
        self.isInInbox = isInInbox
        self.isEvening = isEvening
        self.calendarEventID = calendarEventID
        self.calendarStartAt = calendarStartAt
        self.calendarDurationMinutes = calendarDurationMinutes
        self.reminderItemID = reminderItemID
        self.sortOrder = sortOrder
        self.recurrenceRule = recurrenceRule
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.area = area
        self.project = project
        self.heading = heading
        self.tagAssignments = []
        self.checklist = []
    }
}
