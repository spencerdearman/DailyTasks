//
//  StreakView.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

struct StreakView: View {
    @Query(sort: \DailyTask.createdAt, order: .reverse) private var tasks: [DailyTask]
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("bestStreak") private var bestStreak: Int = 0
    @State var test: Bool = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(currentStreak)")
                        .font(.system(size: 60))
                        .fontWeight(.bold)
                    Text("days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("all tasks completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.accent)
                    Text("Best: \(bestStreak)")
                }
                .font(.caption)
            }
            .navigationTitle("Streak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "Check out my \(currentStreak) day task streak!") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
