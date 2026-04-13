//
//  TaskListView.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyTask.createdAt, order: .reverse) private var tasks: [DailyTask]
    
    @State private var isShowingSheet = false
    @State private var newTaskTitle = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(white: 0.15))
                        )
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
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
                            let inputEmpty = newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            Button(role: .confirm) {
                                addTask()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .disabled(inputEmpty)
                            .tint(inputEmpty ? .clear : .accentColor)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                seedDefaultTasks()
            }
        }
    }
    
    // MARK: - Logic Functions
    
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = DailyTask(title: trimmedTitle)
        modelContext.insert(newTask)
        
        // Reset state
        newTaskTitle = ""
        isShowingSheet = false
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tasks[index])
        }
    }
    
    private func seedDefaultTasks() {
        if tasks.isEmpty {
            let defaults = ["🐕 Walk dog", "🪥 Brush teeth"]
            for title in defaults {
                let task = DailyTask(title: title, streak: 2)
                modelContext.insert(task)
            }
        }
    }
}

struct TaskRow: View {
    @Bindable var task: DailyTask
    
    var body: some View {
        HStack {
            // Completed button
            Button {
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // Task title
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if task.streak > 0 {
                HStack (spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(String(task.streak))
                        .fontWeight(.semibold)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .cornerRadius(20)
            }
        }
    }
}
