//
//  TaskDetailView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct TaskDetailView: View {

    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingReschedule = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(task.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                if let project = task.project {
                    Text(project.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        if task.isCompleted { task.reopen() } else { task.markComplete() }
                        try? modelContext.save()
                        if task.isCompleted { dismiss() }
                    } label: {
                        Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                            .font(.title3.bold())
                            .foregroundColor(task.isCompleted ? .orange : .green)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button { showingReschedule = true } label: {
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
                    Text(task.notes)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }

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
                                        try? modelContext.save()
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
        .confirmationDialog("Reschedule To...", isPresented: $showingReschedule, titleVisibility: .visible) {
            Button("Tomorrow") { reschedule(days: 1) }
            Button("In 3 Days") { reschedule(days: 3) }
            Button("Next Week") { reschedule(days: 7) }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func reschedule(days: Int) {
        if let target = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now)) {
            task.whenDate = target
            task.updatedAt = Date()
            try? modelContext.save()
            dismiss()
        }
    }
}
