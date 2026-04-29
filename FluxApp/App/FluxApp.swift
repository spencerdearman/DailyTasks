//
//  FluxApp.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

@main
struct FluxApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Flux"
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        let modelConfiguration = ModelConfiguration(
            "Flux",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        
        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
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
