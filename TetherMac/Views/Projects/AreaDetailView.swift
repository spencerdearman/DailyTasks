//
//  AreaDetailView.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - AreaDetailView

/// Displays an area's loose tasks and project overview with navigation.
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
    @AppStorage("tetherShowCompletedTasks") private var showCompleted = false

    private var looseTasks: [TaskItem] {
        tasks.filter { $0.project == nil && (showCompleted || !$0.isCompleted) }
    }
    
    private var sortedProjects: [Project] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text(area.title)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Loose tasks (not assigned to any project)
                if !looseTasks.isEmpty {
                    TaskSection(
                        title: "Tasks",
                        tasks: looseTasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    ) { task in
                        toggleTask(task)
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
                    let projectTasks = tasks.filter { $0.project?.id == project.id && (showCompleted || !$0.isCompleted) }
                    if !projectTasks.isEmpty {
                        TaskSection(
                            title: project.title,
                            tasks: projectTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            toggleTask(task)
                        }
                    }
                }
            }
            .padding(28)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    renameText = area.title
                    showRenameAlert = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showRenameAlert) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Rename Area")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.bottom, 16)

                VStack(spacing: 0) {
                    TextField("Area name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer(minLength: 16)

                HStack {
                    Spacer()
                    Button {
                        showRenameAlert = false
                    } label: {
                        Text("Cancel")
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                    Button {
                        let newTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newTitle.isEmpty {
                            area.title = newTitle
                            try? modelContext.save()
                        }
                        showRenameAlert = false
                    } label: {
                        Text("Rename")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 360, height: 180)
            .background(.ultraThinMaterial)
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

    private func toggleTask(_ task: TaskItem) {
        if completingTaskIDs.contains(task.id) {
            withAnimation(.easeInOut(duration: 0.25)) {
                _ = completingTaskIDs.remove(task.id)
            }
            return
        }

        if task.isCompleted {
            task.reopen()
            try? modelContext.save()
        } else {
            _ = withAnimation(.easeInOut(duration: 0.25)) {
                completingTaskIDs.insert(task.id)
            }

            let taskID = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard completingTaskIDs.contains(taskID) else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = completingTaskIDs.remove(taskID)
                    task.markComplete()
                    try? modelContext.save()
                }
            }
        }
    }
}
