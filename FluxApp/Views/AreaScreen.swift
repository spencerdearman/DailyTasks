import SwiftData
import SwiftUI

struct AreaScreen: View {
    let area: Area
    let tasks: [TaskItem]

    @State private var showingQuickEntry = false
    @State private var editingTask: TaskItem?

    private var looseTasks: [TaskItem] {
        tasks.filter { $0.project == nil && !$0.isCompleted }
    }

    private var sortedProjects: [Project] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderCard(title: area.title)

                if !looseTasks.isEmpty {
                    SectionCard(title: "Tasks", count: looseTasks.count) {
                        ForEach(looseTasks) { task in
                            TaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }

                if !sortedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects")
                            .font(.title3.weight(.semibold))
                        ForEach(sortedProjects) { project in
                            NavigationLink(value: SidebarSelection.project(project.id)) {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if !project.goalSummary.isEmpty {
                                            Text(project.goalSummary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Text("\(project.activeTaskCount) active")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.06), in: Capsule())
                                }
                                .padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .pullToQuickFind()
        .background(AppBackground())
        .navigationTitle(area.title)
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
            QuickEntrySheet(defaultSelection: .area(area.id))
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }
}
