//
//  Project.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Project

/// A goal-oriented collection of tasks, optionally nested within an Area.
@Model
final class Project {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var goalSummary: String = ""
    var tintHex: String = "#2E6BC6"
    var sortOrder: Double = 0

    // MARK: Relationships

    var area: Area?

    @Relationship(deleteRule: .cascade, inverse: \Heading.project)
    var headings: [Heading]?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        goalSummary: String = "",
        tintHex: String = "#2E6BC6",
        sortOrder: Double = 0,
        area: Area? = nil
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
