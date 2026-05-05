import SwiftData
import SwiftUI

struct AreaDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let area: Area
    let tasks: [TaskItem]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @Binding var selection: SidebarSelection?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    
    private var looseTasks: [TaskItem] {
        tasks.filter { $0.project == nil && !$0.isCompleted }
    }
    
    private var sortedProjects: [Project] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderCard(title: area.title)
                
                // Loose tasks (not assigned to any project)
                if !looseTasks.isEmpty {
                    TaskSection(
                        title: "Tasks",
                        tasks: looseTasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    ) { task in
                        if task.isCompleted { task.reopen() } else { task.markComplete() }
                        try? modelContext.save()
                    }
                }
                
                // Projects overview
                if !sortedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        VStack(spacing: 0) {
                            ForEach(sortedProjects) { project in
                                Button {
                                    selection = .project(project.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(project.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        // Progress
                                        HStack(spacing: 8) {
                                            if !project.taskList.isEmpty {
                                                Text("\(project.taskList.filter(\.isCompleted).count)/\(project.taskList.count)")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.secondary)
                                                
                                                ProgressView(value: project.completionRatio)
                                                    .frame(width: 48)
                                                    .tint(Color(hex: project.tintHex))
                                            }
                                            
                                            Text("\(project.activeTaskCount) active")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.primary.opacity(0.05), in: Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if project.id != sortedProjects.last?.id {
                                    Divider()
                                        .padding(.leading, 18)
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                
                // Show tasks in each project
                ForEach(sortedProjects) { project in
                    let projectTasks = tasks.filter { $0.project?.id == project.id && !$0.isCompleted }
                    if !projectTasks.isEmpty {
                        TaskSection(
                            title: project.title,
                            tasks: projectTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            if task.isCompleted { task.reopen() } else { task.markComplete() }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .padding(28)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = area.title
                        showRenameAlert = true
                    } label: {
                        Label("Rename Area", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Area", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Rename Area", isPresented: $showRenameAlert) {
            TextField("Area name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let newTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !newTitle.isEmpty {
                    area.title = newTitle
                    try? modelContext.save()
                }
            }
        }
        .alert("Delete Area?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                selection = .inbox
                modelContext.delete(area)
                try? modelContext.save()
            }
        } message: {
            Text("This will delete the area and unassign all its tasks and projects. This cannot be undone.")
        }
    }
}
