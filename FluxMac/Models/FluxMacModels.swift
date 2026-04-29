//
//  FluxMacModels.swift
//  FluxMac
//
//  Created by OpenAI.
//

import Foundation
import SwiftData

enum FluxTaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case someday
    case completed

    var id: String { rawValue }
}

enum FluxSidebarSelection: Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case area(UUID)
    case project(UUID)
}

@Model
final class FluxArea {
    var id: UUID
    var title: String
    var notes: String
    var symbolName: String
    var tintHex: String
    var sortOrder: Double

    @Relationship(deleteRule: .cascade, inverse: \FluxProject.area)
    var projects: [FluxProject]

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.area)
    var tasks: [FluxTask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        symbolName: String = "square.grid.2x2",
        tintHex: String = "#5B83B7",
        sortOrder: Double = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.symbolName = symbolName
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.projects = []
        self.tasks = []
    }
}

@Model
final class FluxProject {
    var id: UUID
    var title: String
    var notes: String
    var goalSummary: String
    var tintHex: String
    var sortOrder: Double

    var area: FluxArea?

    @Relationship(deleteRule: .cascade, inverse: \FluxHeading.project)
    var headings: [FluxHeading]

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.project)
    var tasks: [FluxTask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        goalSummary: String = "",
        tintHex: String = "#2E6BC6",
        sortOrder: Double = 0,
        area: FluxArea? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goalSummary = goalSummary
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.area = area
        self.headings = []
        self.tasks = []
    }
}

@Model
final class FluxHeading {
    var id: UUID
    var title: String
    var notes: String
    var sortOrder: Double

    var project: FluxProject?

    @Relationship(deleteRule: .nullify, inverse: \FluxTask.heading)
    var tasks: [FluxTask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        sortOrder: Double = 0,
        project: FluxProject? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.project = project
        self.tasks = []
    }
}

@Model
final class FluxTag {
    var id: UUID
    var title: String
    var symbolName: String
    var tintHex: String

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "tag",
        tintHex: String = "#8897AA"
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.tintHex = tintHex
    }
}

@Model
final class FluxChecklistItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Double

    var task: FluxTask?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Double = 0,
        task: FluxTask? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.task = task
    }
}

@Model
final class FluxTask {
    var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var whenDate: Date?
    var deadline: Date?
    var completedAt: Date?
    var statusRaw: String
    var isInInbox: Bool
    var isEvening: Bool
    var sortOrder: Double
    var recurrenceRule: String?

    var area: FluxArea?
    var project: FluxProject?
    var heading: FluxHeading?

    var tags: [FluxTag]

    @Relationship(deleteRule: .cascade, inverse: \FluxChecklistItem.task)
    var checklist: [FluxChecklistItem]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        whenDate: Date? = nil,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        status: FluxTaskStatus = .active,
        isInInbox: Bool = true,
        isEvening: Bool = false,
        sortOrder: Double = 0,
        recurrenceRule: String? = nil,
        area: FluxArea? = nil,
        project: FluxProject? = nil,
        heading: FluxHeading? = nil
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
        self.sortOrder = sortOrder
        self.recurrenceRule = recurrenceRule
        self.area = area
        self.project = project
        self.heading = heading
        self.tags = []
        self.checklist = []
    }
}

extension FluxTask {
    var status: FluxTaskStatus {
        get { FluxTaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isCompleted: Bool {
        status == .completed
    }

    var effectiveDate: Date? {
        whenDate ?? deadline
    }

    var plainContext: String {
        [
            title,
            notes,
            area?.title,
            project?.title,
            tags.map(\.title).joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

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

    func markComplete() {
        status = .completed
        completedAt = .now
        updatedAt = .now
    }

    func reopen() {
        status = .active
        completedAt = nil
        updatedAt = .now
    }
}

extension FluxArea {
    var activeTaskCount: Int {
        tasks.filter { !$0.isCompleted && $0.project == nil }.count
            + projects.reduce(0) { $0 + $1.activeTaskCount }
    }
}

extension FluxProject {
    var sortedHeadings: [FluxHeading] {
        headings.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var sortedTasks: [FluxTask] {
        tasks.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var activeTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
    }
}
