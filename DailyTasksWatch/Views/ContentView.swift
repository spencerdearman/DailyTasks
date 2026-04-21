//
//  ContentView.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI

struct ContentView: View {
    @State var selectedTab: Int = 0
    
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

#Preview {
    ContentView()
}
