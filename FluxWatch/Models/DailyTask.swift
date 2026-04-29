//
//  DailyTask.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

@Model
final class DailyTask: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var streak: Int = 0
    var hiddenUntil: Date?
    
    init(title: String, streak: Int = 0, notes: String = "", hiddenUntil: Date? = nil) {
        self.title = title
        self.streak = streak
        self.notes = notes
        self.hiddenUntil = hiddenUntil
    }
}
