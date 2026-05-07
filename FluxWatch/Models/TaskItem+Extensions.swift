//
//  TaskItem+Extensions.swift
//  FluxWatch
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
