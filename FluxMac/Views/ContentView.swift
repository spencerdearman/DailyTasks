//
//  ContentView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView

/// The root view of the app, containing the navigation sidebar and detail views.
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
    @State private var showAgent = false
    @State private var showSynthesis = false
    @State private var currentSynthesis: DailySynthesis?
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""

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
        .toolbar {}
        .background {
            AppBackground()
        }
        .onAppear {
            calendarStore.refresh()
            checkForMorningSynthesis()
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
        .overlay {
            if showAgent {
                AgentOverlay(
                    onDismiss: { showAgent = false },
                    onSelectTask: { taskID in
                        // Find the task and navigate to its context
                        if let task = tasks.first(where: { $0.id == taskID }) {
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
                        }
                        showAgent = false
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showSynthesis, let synthesis = currentSynthesis {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { dismissSynthesis() }

                    SynthesisView(synthesis: synthesis, onDismiss: dismissSynthesis)
                }
                .transition(.opacity)
            }
        }
        .background {
            Button("") {
                if showAgent { showAgent = false }
                showQuickFind.toggle()
            }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            Button("") {
                if showQuickFind { showQuickFind = false }
                withAnimation(.easeOut(duration: 0.25)) { showAgent.toggle() }
            }
                .keyboardShortcut("a", modifiers: .command)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Quick Find")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘F")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
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

            if !unassignedProjects.isEmpty {
                Section("Projects") {
                    ForEach(unassignedProjects) { project in
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
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                .padding(.horizontal, 20)
                .frame(maxWidth: 200)
                .glassEffect(.regular, in: .capsule)
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
                onToggle: toggleTask,
                synthesis: currentSynthesis,
                onOpenSynthesis: { withAnimation { showSynthesis = true } }
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

    private var unassignedProjects: [Project] {
        projects.filter { $0.area == nil }
    }

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
            _ = withAnimation(.easeInOut(duration: 0.25)) {
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

    // MARK: - Daily Synthesis

    private func checkForMorningSynthesis() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Only show before noon
        guard cal.component(.hour, from: .now) < 12 else { return }

        // Check if we already have one for today
        let descriptor = FetchDescriptor<DailySynthesis>(
            predicate: #Predicate { $0.date >= today }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            if !existing.wasDismissed {
                currentSynthesis = existing
                withAnimation { showSynthesis = true }
            }
            return
        }

        // Generate a new one
        guard !geminiAPIKey.isEmpty else { return }

        Task {
            let service = SynthesisService()
            let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
            let completedYesterday = tasks.filter {
                guard let d = $0.completedAt else { return false }
                return d >= yesterday && d < today
            }

            do {
                let result = try await service.generate(
                    activeTasks: activeTasks,
                    calendarEvents: calendarStore.allEvents,
                    areas: areas,
                    completedYesterday: completedYesterday,
                    apiKey: geminiAPIKey
                )

                let overdue = activeTasks.filter {
                    guard let d = $0.effectiveDate else { return false }
                    return d < today
                }

                let synthesis = DailySynthesis(
                    date: today,
                    greeting: result.greeting,
                    conflicts: result.conflicts,
                    overdueCount: overdue.count,
                    suggestedPlan: result.suggestedPlan
                )
                modelContext.insert(synthesis)
                try? modelContext.save()

                currentSynthesis = synthesis
                withAnimation { showSynthesis = true }
            } catch {
                print("[Synthesis] Failed to generate: \(error)")
            }
        }
    }

    private func dismissSynthesis() {
        currentSynthesis?.wasDismissed = true
        try? modelContext.save()
        withAnimation { showSynthesis = false }
    }
}
