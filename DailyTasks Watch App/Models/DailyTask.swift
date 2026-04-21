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
    var title: String = ""
    /// Task notes
    var notes: String = ""
    /// Task completion status
    var isCompleted: Bool = false
    /// Task creation date
    var createdAt: Date = Date()
    /// Task streak
    var streak: Int = 0
    /// Task suspended timeline
    var hiddenUntil: Date?
    
    init(title: String, streak: Int = 0, notes: String = "", hiddenUntil: Date? = nil) {
        self.title = title
        self.streak = streak
        self.notes = notes
        self.hiddenUntil = hiddenUntil
    }
}
