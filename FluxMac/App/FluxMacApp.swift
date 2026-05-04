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
    @StateObject private var calendarStore = CalendarStore()
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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SampleDataSeeder.bootstrapIfNeeded(in: container.mainContext)
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
            AppCommands()
        }
    }
}

private struct AppCommands: Commands {
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
