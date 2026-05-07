//
//  FluxWatchApp.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

@main
struct FluxWatchApp: App {

    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Flux"

    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            Area.self,
            Project.self,
            Heading.self,
            TaskItem.self,
            ChecklistItem.self,
            Tag.self,
            TaskTagAssignment.self
        ])

        let modelConfiguration = ModelConfiguration(
            "Flux",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
