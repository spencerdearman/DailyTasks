//
//  TaskManager.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

@MainActor
class TaskManager {
    static let shared = TaskManager()
    var modelContainer: ModelContainer?
    var context: ModelContext {
        guard let container = modelContainer else {
            fatalError("TaskManager must be initialized with a ModelContainer.")
        }
        return container.mainContext
    }
    
    private init() {}
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }
}
