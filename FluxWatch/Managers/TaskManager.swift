//
//  TaskManager.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskManager

/// Singleton that holds a reference to the shared `ModelContainer` for task persistence.
@MainActor
class TaskManager {

    // MARK: - Properties

    static let shared = TaskManager()

    var modelContainer: ModelContainer?

    var context: ModelContext {
        guard let container = modelContainer else {
            fatalError("TaskManager must be initialized with a ModelContainer.")
        }
        return container.mainContext
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Methods

    /// Configures the manager with the given model container.
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }
}
