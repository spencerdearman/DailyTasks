//
//  TaskRowView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskRowView

/// A single row representing a task in the task list, with toggle and streak badge.
struct TaskRowView: View {

    // MARK: - Properties

    @Bindable var task: DailyTask
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        HStack {
            Button {
                task.isCompleted.toggle()
                saveChanges()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.gray)
            }
            .buttonStyle(.plain)
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)

            Spacer()

            if task.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text(String(task.streak))
                        .fontWeight(.semibold)
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(20)
            }
        }
    }

    // MARK: - Private Methods

    /// Persists any pending model context changes.
    private func saveChanges() {
        guard modelContext.hasChanges else { return }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Flux changes: \(error)")
        }
    }
}
