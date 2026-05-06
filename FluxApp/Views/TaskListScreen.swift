import SwiftData
import SwiftUI

struct TaskListScreen: View {
    let title: String
    let tasks: [TaskItem]
    let defaultSelection: SidebarSelection?

    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var editingTask: TaskItem?

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
