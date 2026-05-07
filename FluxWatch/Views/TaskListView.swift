//
//  TaskListView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct TaskListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<TaskItem> { task in
            task.statusRaw != "completed" && task.statusRaw != "someday"
        },
        sort: \TaskItem.sortOrder
    ) private var activeTasks: [TaskItem]

    @State private var isShowingSheet = false
    @State private var newTaskTitle = ""

    private var todayTasks: [TaskItem] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        return activeTasks.filter { task in
            guard let whenDate = task.whenDate else { return false }
            return whenDate < tomorrow
        }
    }

    private var completedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if todayTasks.isEmpty {
                    ContentUnavailableView("No Tasks Today", systemImage: "checkmark.seal.fill")
                } else {
                    List {
                        ForEach(todayTasks) { task in
                            NavigationLink(value: task) {
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !todayTasks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("\(completedCount)/\(todayTasks.count)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $isShowingSheet) {
                NavigationStack {
                    Form {
                        TextField("Task Title", text: $newTaskTitle)
                    }
                    .navigationTitle("New Task")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) {
                                isShowingSheet = false
                                newTaskTitle = ""
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            let isEmpty = newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            Button(role: .confirm) {
                                addTask()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .disabled(isEmpty)
                            .tint(isEmpty ? .clear : .accentColor)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(
            title: trimmed,
            whenDate: Calendar.current.startOfDay(for: .now),
            isInInbox: false
        )
        modelContext.insert(task)
        try? modelContext.save()
        newTaskTitle = ""
        isShowingSheet = false
    }
}
