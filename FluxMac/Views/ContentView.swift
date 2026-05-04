import SwiftData
import SwiftUI

//
//  ContentView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var calendarStore: CalendarStore
    
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    
    @State private var selection: SidebarSelection? = .inbox
    @State private var showQuickEntrySheet = false
    @State private var showNewProjectSheet = false
    @State private var showNewAreaSheet = false
    @State private var showSettingsSheet = false
    @State private var expandedTaskID: UUID?
    @State private var completingTaskIDs: Set<UUID> = []
    @State private var showQuickFind = false
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContainer
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showQuickEntrySheet) {
            QuickEntryView(defaultSelection: selection)
        }
        .sheet(isPresented: $showNewProjectSheet) {
            NewProjectSheet()
        }
        .sheet(isPresented: $showNewAreaSheet) {
            NewAreaSheet()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet()
        }
        .tint(.primary)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if case .project(let id) = selection {
                    Button {
                        openWindow(value: id)
                    } label: {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open in Window")
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white, Color(white: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            calendarStore.refresh()
        }
        .focusedSceneValue(\.selectedProjectID, selectedProjectID)
        .overlay {
            if showQuickFind {
                QuickFindOverlay(
                    areas: areas,
                    projects: projects,
                    tasks: tasks,
                    onSelectSidebar: { sel in
                        selection = sel
                        showQuickFind = false
                    },
                    onSelectTask: { task in
                        // Navigate to the task's context and expand it
                        if let project = task.project {
                            selection = .project(project.id)
                        } else if let area = task.area {
                            selection = .area(area.id)
                        } else if task.isInInbox {
                            selection = .inbox
                        } else if task.status == .someday {
                            selection = .someday
                        } else {
                            selection = .anytime
                        }
                        expandedTaskID = task.id
                        showQuickFind = false
                    },
                    onDismiss: {
                        showQuickFind = false
                    }
                )
            }
        }
        .background {
            Button("") { showQuickFind.toggle() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: $selection) {
            // Quick Find button
            Button {
                showQuickFind = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Quick Find")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘F")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .listRowSeparator(.hidden)
            
            Section("Core") {
                navLink("Inbox", systemImage: "tray.fill", selection: .inbox, count: inboxTasks.count)
                navLink("Today", systemImage: "sun.max.fill", selection: .today, count: todayTasks.count)
                navLink("Upcoming", systemImage: "calendar", selection: .upcoming, count: upcomingTasks.count)
                navLink("Open", systemImage: "tray.2.fill", selection: .anytime, count: anytimeTasks.count)
                navLink("Later", systemImage: "moon.zzz.fill", selection: .someday, count: somedayTasks.count)
                navLink("Done", systemImage: "checkmark.circle.fill", selection: .logbook, count: logbookTasks.count)
            }
            
            Section("Areas") {
                ForEach(filteredAreas) { area in
                    // Area row — tapping navigates to area detail
                    NavigationLink(value: SidebarSelection.area(area.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: area.symbolName)
                                .foregroundStyle(Color(hex: area.tintHex))
                            Text(area.title)
                            Spacer()
                            Text("\(area.activeTaskCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        _ = reassign(tasks: items, to: area)
                    }
                    
                    // Projects under the area (indented)
                    ForEach(filteredProjects(in: area)) { project in
                        NavigationLink(value: SidebarSelection.project(project.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: "paperplane")
                                Text(project.title)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(project.activeTaskCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 20)
                        .dropDestination(for: String.self) { items, _ in
                            _ = reassign(tasks: items, to: project, in: area)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button {
                        showNewProjectSheet = true
                    } label: {
                        Label("New Project", systemImage: "list.bullet")
                    }
                    
                    Divider()
                    
                    Button {
                        showNewAreaSheet = true
                    } label: {
                        Label("New Area", systemImage: "square.grid.2x2")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New List")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                
                Spacer()
                
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gear")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(10)
        }
    }
    
    // MARK: - Detail
    
    private var detailContainer: some View {
        detailContent
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 0) {
                    detailFooterTab(systemImage: "plus", label: "New") {
                        showQuickEntrySheet = true
                    }
                    detailFooterTab(systemImage: "calendar", label: "Today") {
                        selection = .today
                    }
                    detailFooterTab(systemImage: "arrow.down.circle", label: "Import") {
                        calendarStore.importReminders(into: modelContext, areas: areas)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                .padding(.horizontal, 20)
                .frame(maxWidth: 260)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
                .padding(.bottom, 12)
            }
    }
    
    private func detailFooterTab(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .inbox {
        case .inbox:
            TaskCollectionView(
                title: "Inbox",
                tasks: inboxTasks,
                events: [],
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .today:
            TaskCollectionView(
                title: "Today",
                tasks: todayTasks,
                eveningTasks: eveningTasks,
                events: calendarStore.todayEvents,
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .upcoming:
            TaskCollectionView(
                title: "Upcoming",
                tasks: upcomingTasks,
                events: calendarStore.upcomingEvents,
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .anytime:
            TaskCollectionView(
                title: "Open",
                tasks: anytimeTasks,
                events: [],
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .someday:
            TaskCollectionView(
                title: "Later",
                tasks: somedayTasks,
                events: [],
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .logbook:
            TaskCollectionView(
                title: "Done",
                tasks: logbookTasks,
                events: [],
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        case .area(let id):
            if let area = areas.first(where: { $0.id == id }) {
                AreaDetailView(
                    area: area,
                    tasks: tasksForArea(area),
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    selection: $selection
                )
            } else {
                ContentUnavailableView("Area unavailable", systemImage: "rectangle.stack.badge.minus")
            }
        case .project(let id):
            if let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(
                    project: project,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs
                )
            } else {
                ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
            }
        }
    }
    
    // MARK: - Data
    
    private var filteredAreas: [Area] { areas }
    
    private func filteredProjects(in area: Area) -> [Project] {
        projects.filter { $0.area?.id == area.id }
    }
    
    private var inboxTasks: [TaskItem] { activeTasks.filter(\.isInInbox) }
    private var todayTasks: [TaskItem] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && !$0.isEvening
        }
    }
    private var eveningTasks: [TaskItem] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && $0.isEvening
        }
    }
    private var upcomingTasks: [TaskItem] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return activeTasks.filter {
            guard let date = $0.effectiveDate else { return false }
            return date >= tomorrow
        }
    }
    private var anytimeTasks: [TaskItem] { activeTasks.filter { !$0.isInInbox && $0.whenDate == nil } }
    private var somedayTasks: [TaskItem] { tasks.filter { $0.status == .someday } }
    private var logbookTasks: [TaskItem] {
        tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    private var activeTasks: [TaskItem] { tasks.filter { $0.status == .active } }
    
    private var selectedProjectID: UUID? {
        if case .project(let id) = selection { return id }
        return nil
    }
    
    private func tasksForArea(_ area: Area) -> [TaskItem] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }
    
    // MARK: - Actions
    
    private func toggleTask(_ task: TaskItem) {
        if completingTaskIDs.contains(task.id) {
            // User tapped again while completing — undo
            withAnimation(.easeInOut(duration: 0.25)) {
                _ = completingTaskIDs.remove(task.id)
            }
            return
        }
        
        if task.isCompleted {
            // Reopen immediately
            task.reopen()
            try? modelContext.save()
        } else {
            // Show completed look immediately, but delay actual status change
            withAnimation(.easeInOut(duration: 0.25)) {
                completingTaskIDs.insert(task.id)
            }
            
            // After a few seconds, actually mark complete and remove from list
            let taskID = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // Only if still in completing set (user didn't undo)
                guard completingTaskIDs.contains(taskID) else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = completingTaskIDs.remove(taskID)
                    task.markComplete()
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func reassign(tasks ids: [String], to area: Area) -> Bool {
        let matchedTasks = tasks.filter { ids.contains($0.id.uuidString) }
        for task in matchedTasks {
            task.area = area
            task.project = nil
            task.heading = nil
            task.isInInbox = false
            task.updatedAt = .now
        }
        try? modelContext.save()
        return !matchedTasks.isEmpty
    }
    
    private func reassign(tasks ids: [String], to project: Project, in area: Area) -> Bool {
        let matchedTasks = tasks.filter { ids.contains($0.id.uuidString) }
        for task in matchedTasks {
            task.area = area
            task.project = project
            task.heading = nil
            task.isInInbox = false
            task.updatedAt = .now
        }
        try? modelContext.save()
        return !matchedTasks.isEmpty
    }
    
    // MARK: - Helpers
    
    private func navLink(_ title: String, systemImage: String, selection: SidebarSelection, count: Int) -> some View {
        NavigationLink(value: selection) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
}
