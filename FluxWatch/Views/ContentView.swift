//
//  ContentView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - ContentView

/// Root tab view that hosts the primary navigation tabs for the Watch app.
struct ContentView: View {

    // MARK: - Properties

    @State var selectedTab: Int = 0

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Tasks", systemImage: "checkmark.circle", value: 0) {
                TaskListView()
            }

            Tab("Streak", systemImage: "flame.fill", value: 1) {
                StreakView()
            }

            Tab("Reminder", systemImage: "bell.fill", value: 2) {
                ReminderView()
            }

#if DEBUG
            Tab("Debug", systemImage: "ladybug.fill", value: 3) {
                DebugView()
            }
#endif
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
