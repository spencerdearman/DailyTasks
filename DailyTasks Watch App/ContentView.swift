//
//  ContentView.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI

struct ContentView: View {
    @State var selectedTab: Int = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab("Tasks", systemImage: "checkmark.circle", value: 0) {
                    TaskListView()
                }
                
                Tab("Streak", systemImage: "flame.fill", value: 1) {
                    StreakView()
                }
                
                Tab("Reminder", systemImage: "bell.fill", value: 2) {
                    TaskListView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
