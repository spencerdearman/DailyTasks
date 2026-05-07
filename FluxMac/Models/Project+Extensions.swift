//
//  Project+Extensions.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

extension Project {

    /// All headings in this project, safely unwrapped.
    var headingList: [Heading] {
        headings ?? []
    }

    /// All tasks in this project, safely unwrapped.
    var taskList: [TaskItem] {
        tasks ?? []
    }

    /// Headings sorted by sort order, then alphabetically.
    var sortedHeadings: [Heading] {
        headingList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    /// Tasks sorted by sort order, then creation date.
    var sortedTasks: [TaskItem] {
        taskList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    /// The number of tasks that are not yet completed.
    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted }.count
    }

    /// The fraction of tasks that have been completed (0.0 to 1.0).
    var completionRatio: Double {
        guard !taskList.isEmpty else { return 0 }
        return Double(taskList.filter(\.isCompleted).count) / Double(taskList.count)
    }
}
