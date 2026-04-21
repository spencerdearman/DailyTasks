//
//  ContentView.swift
//  DailyTasksApp
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \DailyTask.createdAt) private var tasks: [DailyTask]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isShowingSheet = false
    
    var visibleTasks: [DailyTask] {
        tasks.filter { task in
            if let hiddenDate = task.hiddenUntil {
                return hiddenDate <= Date()
            }
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if visibleTasks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 80))
                                .foregroundStyle(Color.accentColor.opacity(0.8))
                            Text("No active tasks.")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(visibleTasks) { task in
                                iOS_TaskRow(task: task)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(task)
                                            saveChanges()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .listStyle(.plain)
                        .padding(.top, 10)
                    }
                }
            }
            .navigationTitle("Daily Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .sheet(isPresented: $isShowingSheet) {
                iOS_AddTaskView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Daily Tasks changes: \(error)")
        }
    }
}

// MARK: Row
struct iOS_TaskRow: View {
    @Bindable var task: DailyTask
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Button(action: {
            withAnimation(.spring) {
                task.isCompleted.toggle()
                if task.isCompleted {
                    task.streak += 1
                } else {
                    task.streak = max(0, task.streak - 1)
                }
            }
            saveChanges()
        }) {
            HStack(spacing: 18) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.gray.opacity(0.5))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                if task.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("\(task.streak)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(.regularMaterial)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
    
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Daily Tasks changes: \(error)")
        }
    }
}

// MARK: Add Task
struct iOS_AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task Name", text: $title)
                        .font(.headline)
                        .padding(.vertical, 4)
                } header: {
                    Text("What's your goal?")
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes (Optional)")
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newTask = DailyTask(title: title, streak: 0, notes: notes)
                        modelContext.insert(newTask)
                        saveChanges()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Daily Tasks changes: \(error)")
        }
    }
}
