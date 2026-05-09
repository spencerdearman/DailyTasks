//
//  TetherApp.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import GoogleSignIn
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.spencerdearman.Tether", category: "CloudKit")

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
            DailySynthesis.self,
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

            let ctx = container.mainContext
            let taskCount = (try? ctx.fetchCount(FetchDescriptor<TaskItem>())) ?? -1
            let synthCount = (try? ctx.fetchCount(FetchDescriptor<DailySynthesis>())) ?? -1
            logger.info("☁️ [iOS] CloudKit container ready — \(taskCount) tasks, \(synthCount) syntheses")
            logger.info("☁️ [iOS] Schema models: Area, Project, Heading, TaskItem, ChecklistItem, Tag, TaskTagAssignment, DailySynthesis, AgentConversation")
            logger.info("☁️ [iOS] CloudKit DB: \(Self.cloudKitContainerIdentifier)")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: Body

    @StateObject private var calendarStore = CalendarStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarStore)
                .onAppear {
                    calendarStore.restoreGoogleSignIn()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
