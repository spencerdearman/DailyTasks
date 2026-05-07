//
//  ProjectDetailView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - ProjectDetailView

/// The full detail view for a project, showing headings, tasks, and inline editing.
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    let project: Project
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @State private var newHeadingTitle = ""
    @State private var showAddHeading = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(project.title)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Simple notes editor
                TextField("Notes…", text: Binding(
                    get: { project.notes },
                    set: {
                        project.notes = $0
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(2...10)
                .padding(16)
                .frame(minHeight: 56, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id }
                    VStack(alignment: .leading, spacing: 8) {
                        if headingTasks.isEmpty {
                            // Just show heading title when no tasks
                            HStack {
                                Text(heading.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("0")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            TaskSection(
                                title: heading.title,
                                tasks: headingTasks,
                                expandedTaskID: $expandedTaskID,
                                completingTaskIDs: $completingTaskIDs
                            ) { task in
                                toggleTask(task)
                            }
                        }

                        InlineTaskAdder(
                            project: project,
                            area: project.area,
                            heading: heading
                        )
                    }
                }

                let ungroupedTasks = project.sortedTasks.filter { $0.heading == nil }
                VStack(alignment: .leading, spacing: 8) {
                    if !ungroupedTasks.isEmpty {
                        TaskSection(
                            title: "Tasks",
                            tasks: ungroupedTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            toggleTask(task)
                        }
                    }
                    
                    InlineTaskAdder(
                        project: project,
                        area: project.area,
                        heading: nil
                    )
                }
                
                // Add heading
                if showAddHeading {
                    HStack(spacing: 10) {
                        TextField("Heading name…", text: $newHeadingTitle)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .onSubmit { addHeading() }
                        
                        Button("Add") { addHeading() }
                            .buttonStyle(.bordered)
                            .disabled(newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button { showAddHeading = false; newHeadingTitle = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                } else {
                    Button {
                        showAddHeading = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Heading")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(28)
        }
        .background(Color.clear)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openWindow(value: project.id)
                } label: {
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button {
                    renameText = project.title
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
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let newTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !newTitle.isEmpty {
                    project.title = newTitle
                    try? modelContext.save()
                }
            }
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(project)
                try? modelContext.save()
            }
        } message: {
            Text("This will delete the project and unassign all its tasks. This cannot be undone.")
        }
    }
    
    private func addHeading() {
        let title = newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let heading = Heading(
            title: title,
            sortOrder: Double(project.headingList.count),
            project: project
        )
        modelContext.insert(heading)
        try? modelContext.save()
        newHeadingTitle = ""
        showAddHeading = false
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
