import SwiftData
import SwiftUI

struct ProjectScreen: View {
    let project: Project

    @State private var showingQuickEntry = false
    @State private var editingTask: TaskItem?

    private var ungroupedTasks: [TaskItem] {
        project.sortedTasks.filter { $0.heading == nil && !$0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderCard(title: project.title)

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
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            QuickEntrySheet(defaultSelection: .project(project.id))
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }
}
