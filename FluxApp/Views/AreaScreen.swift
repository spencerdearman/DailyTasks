//
//  AreaScreen.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - AreaScreen

/// Displays an area's loose tasks and nested projects.
struct AreaScreen: View {

    // MARK: - Properties

    let area: Area
    let tasks: [TaskItem]

    // MARK: - State

    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var editingTask: TaskItem?

    // MARK: - Computed Properties

    private var looseTasks: [TaskItem] {
        tasks.filter { $0.project == nil && !$0.isCompleted }
    }

    private var sortedProjects: [Project] {
        area.projectList.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
            QuickEntrySheet(defaultSelection: .area(area.id))
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
