//
//  Area+Extensions.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

extension Area {

    /// All projects in this area, safely unwrapped.
    var projectList: [Project] {
        projects ?? []
    }

    /// All tasks directly assigned to this area, safely unwrapped.
    var taskList: [TaskItem] {
        tasks ?? []
    }

    /// The total number of active tasks across the area and its projects.
    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted && $0.project == nil }.count
            + projectList.reduce(0) { $0 + $1.activeTaskCount }
    }
}
