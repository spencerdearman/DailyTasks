//
//  StreakView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - StreakView

/// Displays the user's current and best task-completion streaks.
struct StreakView: View {

    // MARK: - Properties

    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("bestStreak") private var bestStreak: Int = 0

    // MARK: - Body

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
