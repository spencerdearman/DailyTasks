//
//  TaskRowView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskRowView

/// A single row representing a task in the task list, with toggle and project badge.
struct TaskRowView: View {

    // MARK: - Properties

    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        HStack {
            Button {
                if task.isCompleted {
                    task.reopen()
                } else {
                    task.markComplete()
                }
                saveChanges()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let project = task.project {
                    Text(project.title)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if task.deadline != nil {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
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
