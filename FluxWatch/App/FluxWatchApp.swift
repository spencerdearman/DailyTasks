//
//  FluxWatchApp.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct FluxWatchApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.com.spencerdearman.Flux"
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) var delegate
    let sharedModelContainer: ModelContainer
    
    init() {
        let schema = Schema([DailyTask.self])
        
        let modelConfiguration = ModelConfiguration(
            "Flux",
            schema: schema,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            TaskManager.shared.configure(with: container)
            Self.logCloudKitAccountStatus()
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
    
    private static func logCloudKitAccountStatus() {
        CKContainer(identifier: cloudKitContainerIdentifier).accountStatus { status, error in
            if let error {
                print("Watch CloudKit account status error: \(error.localizedDescription)")
                return
            }
            
            let description: String
            switch status {
            case .available:
                description = "available"
            case .noAccount:
                description = "noAccount"
            case .restricted:
                description = "restricted"
            case .couldNotDetermine:
                description = "couldNotDetermine"
            case .temporarilyUnavailable:
                description = "temporarilyUnavailable"
            @unknown default:
                description = "unknown"
            }
            
            print("Watch CloudKit account status: \(description)")
        }
    }
}
