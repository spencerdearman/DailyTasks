//
//  TaskManager.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI
import SwiftData

@MainActor
class TaskManager {
    /// Shared TaskManager instance
    static let shared = TaskManager()
    /// Store th emodelContainer injected on app startup
    var modelContainer: ModelContainer?
    /// Computed property to access the modelContainer automatically
    var context: ModelContext {
        guard let container = modelContainer else {
            fatalError("TaskManager must be initialized with a ModelContainer.")
        }
        return container.mainContext
    }
    
    private init() {}
    
    /// Configuration function for modelContainer
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }
}
