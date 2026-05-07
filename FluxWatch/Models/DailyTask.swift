//
//  DailyTask.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - DailyTask

/// A persisted daily task model that tracks completion state, streaks, and deferred visibility.
@Model
final class DailyTask: Identifiable {

    // MARK: - Properties

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var streak: Int = 0
    var hiddenUntil: Date?

    // MARK: - Initialization

    init(title: String, streak: Int = 0, notes: String = "", hiddenUntil: Date? = nil) {
        self.title = title
        self.streak = streak
        self.notes = notes
        self.hiddenUntil = hiddenUntil
    }
}
