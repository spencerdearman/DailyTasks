//
//  Heading.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Heading

/// A named section within a project used to group related tasks.
@Model
final class Heading {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var sortOrder: Double = 0

    // MARK: Relationships

    var project: Project?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.heading)
    var tasks: [TaskItem]?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        sortOrder: Double = 0,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.project = project
        self.tasks = []
    }
}
