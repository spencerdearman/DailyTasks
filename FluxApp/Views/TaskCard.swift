//
//  TaskCard.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskCard

/// A card displaying a single task with a completion toggle, metadata badges, and notes preview.
struct TaskCard: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Properties

    @Bindable var task: TaskItem
    let onOpen: () -> Void

    // MARK: - State

    @State private var isCompleting = false

    // MARK: - Computed Properties

    private var isDone: Bool { isCompleting || task.isCompleted }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                toggleTask()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !task.tagList.isEmpty || task.area != nil || task.project != nil || task.effectiveDate != nil || !task.checklistItems.isEmpty {
                        TaskMeta(task: task)
                    }

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isCompleting ? 0.5 : 1.0)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                toggleTask()
            }
        }
    }

    // MARK: - Actions

    /// Toggles the task between complete and incomplete with a delayed commit.
    private func toggleTask() {
        if isCompleting {
            // User tapped again while completing -- undo
            withAnimation(.easeInOut(duration: 0.25)) {
                isCompleting = false
            }
            return
        }

        if task.isCompleted {
            task.reopen()
            try? modelContext.save()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCompleting = true
            }

            let taskID = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard isCompleting else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    isCompleting = false
                    task.markComplete()
                    try? modelContext.save()
                }
            }
        }
    }
}
