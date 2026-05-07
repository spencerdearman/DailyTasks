//
//  TaskListScreen.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - TaskListScreen

/// Displays a scrollable list of tasks for a given sidebar category (Inbox, Today, etc.).
struct TaskListScreen: View {

    // MARK: - Properties

    let title: String
    let tasks: [TaskItem]
    let defaultSelection: SidebarSelection?

    // MARK: - State

    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var editingTask: TaskItem?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if tasks.isEmpty {
                    EmptyCard(title: title)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(tasks) { task in
                            TaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .pullToQuickFind()
        .background(AppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingQuickEntry = true } label: {
                        Label("New Task", systemImage: "checkmark.circle")
                    }
                    Button { showingNewProject = true } label: {
                        Label("New Project", systemImage: "paperplane")
                    }
                    Button { showingNewArea = true } label: {
                        Label("New Area", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            QuickEntrySheet(defaultSelection: defaultSelection)
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet()
        }
        .sheet(isPresented: $showingNewArea) {
            NewAreaSheet()
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }
}
