//
//  ChecklistItem.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - ChecklistItem

/// A subtask within a parent task's checklist.
@Model
final class ChecklistItem {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var sortOrder: Double = 0

    // MARK: Relationships

    var task: TaskItem?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Double = 0,
        task: TaskItem? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.task = task
    }
}
