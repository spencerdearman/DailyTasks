//
//  TaskTagAssignment.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - TaskTagAssignment

/// A join model linking a task to a tag (many-to-many relationship).
@Model
final class TaskTagAssignment {

    // MARK: Properties

    var id: UUID = UUID()

    // MARK: Relationships

    var task: TaskItem?
    var tag: Tag?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        tag: Tag? = nil
    ) {
        self.id = id
        self.task = task
        self.tag = tag
    }
}
