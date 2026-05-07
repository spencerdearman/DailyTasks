//
//  TaskDetailView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskDetailView

/// Displays details for a single task with options to complete, defer, or view notes.
struct TaskDetailView: View {

    // MARK: - Properties

    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingPushOptions = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(task.title)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                if let project = task.project {
                    Text(project.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            if task.isCompleted {
                                task.reopen()
                            } else {
                                task.markComplete()
                            }
                        }
                        saveChanges()
                        if task.isCompleted {
                            dismiss()
                        }
                    }) {
                        Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            .font(.title3.bold())
                            .foregroundColor(task.isCompleted ? .orange : .green)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingPushOptions = true
                    } label: {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)

                if !task.notes.isEmpty {
                    VStack(alignment: .leading) {
                        Text(task.notes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }

                // Checklist
                let items = task.checklist?.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundStyle(item.isCompleted ? Color.accentColor : .gray)
                                    .onTapGesture {
                                        item.isCompleted.toggle()
                                        saveChanges()
                                    }
                                Text(item.title)
                                    .font(.subheadline)
                                    .strikethrough(item.isCompleted)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }

                if let deadline = task.deadline {
                    HStack {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Due \(deadline, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveChanges()
        }
        .confirmationDialog("Reschedule To...", isPresented: $showingPushOptions, titleVisibility: .visible) {
            Button("Tomorrow") { pushTask(days: 1) }
            Button("In 3 Days") { pushTask(days: 3) }
            Button("Next Week") { pushTask(days: 7) }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Private Methods

    /// Reschedules a task forward by the specified number of days.
    private func pushTask(days: Int) {
        let calendar = Calendar.current
        if let targetDate = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now)) {
            task.whenDate = targetDate
            task.updatedAt = Date()
            saveChanges()
            dismiss()
        }
    }

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
