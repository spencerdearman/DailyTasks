//
//  DailySynthesis.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - DailySynthesis

/// A persisted daily briefing generated overnight by the synthesis engine.
@Model
final class DailySynthesis {

    // MARK: Persisted Properties

    var id: UUID = UUID()
    var date: Date = Date()
    var generatedAt: Date = Date()
    var greeting: String = ""
    var conflictsJSON: String = "[]"
    var overdueCount: Int = 0
    var suggestedPlan: String = ""
    var wasDismissed: Bool = false

    // MARK: Computed Properties

    /// Decoded array of conflict descriptions from the stored JSON.
    var conflicts: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(conflictsJSON.utf8))) ?? []
        }
        set {
            conflictsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    // MARK: Initialization

    init(
        date: Date,
        greeting: String,
        conflicts: [String] = [],
        overdueCount: Int = 0,
        suggestedPlan: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.generatedAt = Date()
        self.greeting = greeting
        self.overdueCount = overdueCount
        self.suggestedPlan = suggestedPlan
        self.wasDismissed = false
        self.conflictsJSON = (try? String(data: JSONEncoder().encode(conflicts), encoding: .utf8)) ?? "[]"
    }
}
