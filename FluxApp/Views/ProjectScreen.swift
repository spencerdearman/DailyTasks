import SwiftData
import SwiftUI

struct ProjectScreen: View {
    let project: Project

    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var editingTask: TaskItem?

    private var ungroupedTasks: [TaskItem] {
        project.sortedTasks.filter { $0.heading == nil && !$0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !project.notes.isEmpty {
                    Text(project.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if !ungroupedTasks.isEmpty {
                    SectionCard(title: "Tasks", count: ungroupedTasks.count) {
                        ForEach(ungroupedTasks) { task in
                            TaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }

                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id && !$0.isCompleted }
                    if !headingTasks.isEmpty {
                        SectionCard(title: heading.title, count: headingTasks.count) {
                            ForEach(headingTasks) { task in
                                TaskCard(task: task) {
                                    editingTask = task
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .pullToQuickFind()
        .background(AppBackground())
        .navigationTitle(project.title)
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
            QuickEntrySheet(defaultSelection: .project(project.id))
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
