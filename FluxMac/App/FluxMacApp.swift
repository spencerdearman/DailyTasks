//
//  FluxMacApp.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

@main
struct FluxMacApp: App {
    @StateObject private var calendarStore = FluxCalendarStore()
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([
            FluxArea.self,
            FluxProject.self,
            FluxHeading.self,
            FluxTask.self,
            FluxChecklistItem.self,
            FluxTag.self
        ])
        let modelConfiguration = ModelConfiguration(
            "FluxMacWorkspace",
            schema: schema
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            FluxMacSampleDataSeeder.bootstrapIfNeeded(in: container.mainContext)
            self.sharedModelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environmentObject(calendarStore)
                .modelContainer(sharedModelContainer)
        }
        .defaultSize(width: 1320, height: 860)

        Window("Quick Entry", id: "quick-entry") {
            QuickEntryView(defaultSelection: .inbox)
                .environmentObject(calendarStore)
                .modelContainer(sharedModelContainer)
        }
        .defaultSize(width: 560, height: 560)

        WindowGroup("Project", for: UUID.self) { $projectID in
            ProjectWindowView(projectID: projectID)
                .environmentObject(calendarStore)
                .modelContainer(sharedModelContainer)
        }
        .defaultSize(width: 820, height: 720)
        .commands {
            FluxMacCommands()
        }
    }
}

private struct FluxMacCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.selectedProjectID) private var selectedProjectID

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Quick Entry") {
                openWindow(id: "quick-entry")
            }
            .keyboardShortcut(" ", modifiers: [.command, .option])

            Button("Open Project in New Window") {
                guard let selectedProjectID else { return }
                openWindow(value: selectedProjectID)
            }
            .keyboardShortcut("N", modifiers: [.command, .shift])
            .disabled(selectedProjectID == nil)
        }
    }
}
