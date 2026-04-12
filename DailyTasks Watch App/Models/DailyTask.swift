//
//  DailyTask.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman on 4/12/26.
//

import Foundation
import SwiftData

@Model
final class DailyTask: Identifiable {
    /// Task ID
    var id: UUID = UUID()
    /// Task title
    var title: String
    /// Task completion status
    var isCompleted: Bool = false
    /// Task creation date
    var createdAt: Date = Date()
    /// Task streak
    var streak: Int = 0
    
    init(title: String) {
        self.title = title
    }
}
