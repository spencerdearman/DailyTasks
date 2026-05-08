//
//  TetherApp.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TetherApp

/// The main entry point for the Tether application.
@main
struct TetherApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Tether"
    let sharedModelContainer: ModelContainer

    // MARK: Initialization

    init() {
        let schema = Schema([
            Area.self,
            Project.self,
            Heading.self,
            TaskItem.self,
            ChecklistItem.self,
            Tag.self,
            TaskTagAssignment.self,
            AgentConversation.self
        ])
        let modelConfiguration = ModelConfiguration(
            "Tether",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SampleDataSeeder.bootstrapIfNeeded(in: container.mainContext)
            self.sharedModelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: Body

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
