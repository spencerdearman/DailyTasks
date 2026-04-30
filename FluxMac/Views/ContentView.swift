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
    @EnvironmentObject private var calendarStore: FluxCalendarStore

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]
    @Query(sort: \FluxTask.createdAt, order: .reverse) private var tasks: [FluxTask]

    @State private var selection: FluxSidebarSelection? = .inbox
    @State private var searchText = ""
    @State private var showQuickEntrySheet = false
    @State private var showNewProjectSheet = false
    @State private var showNewAreaSheet = false
    @State private var showSettingsSheet = false
    @State private var expandedTaskID: UUID?
    @State private var completingTaskIDs: Set<UUID> = []

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContainer
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search tasks…")
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
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
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
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
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
                    DisclosureGroup {
                        ForEach(filteredProjects(in: area)) { project in
                            NavigationLink(value: FluxSidebarSelection.project(project.id)) {
                                HStack(spacing: 10) {
                                    Image(systemName: "paperplane")
                                    Text(project.title)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(project.activeTaskCount)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onTapGesture(count: 2) {
                                openWindow(value: project.id)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                _ = reassign(tasks: items, to: project, in: area)
                            }
                        }
                    } label: {
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
                    Image(systemName: "gearshape")
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
                .font(.caption2)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .padding(.horizontal, 16)
                .frame(maxWidth: 280)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                .padding(.bottom, 10)
            }
    }

    private func detailFooterTab(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailContent: some View {
        if !searchText.isEmpty {
            FluxTaskCollectionView(
                title: "Search",
                tasks: searchResults,
                events: [],
                expandedTaskID: $expandedTaskID,
                completingTaskIDs: $completingTaskIDs,
                onToggle: toggleTask
            )
        } else {
            switch selection ?? .inbox {
            case .inbox:
                FluxTaskCollectionView(
                    title: "Inbox",
                    tasks: inboxTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .today:
                FluxTaskCollectionView(
                    title: "Today",
                    tasks: todayTasks,
                    eveningTasks: eveningTasks,
                    events: calendarStore.todayEvents,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .upcoming:
                FluxTaskCollectionView(
                    title: "Upcoming",
                    tasks: upcomingTasks,
                    events: calendarStore.upcomingEvents,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .anytime:
                FluxTaskCollectionView(
                    title: "Open",
                    tasks: anytimeTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .someday:
                FluxTaskCollectionView(
                    title: "Later",
                    tasks: somedayTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .logbook:
                FluxTaskCollectionView(
                    title: "Done",
                    tasks: logbookTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .area(let id):
                if let area = areas.first(where: { $0.id == id }) {
                    FluxAreaDetailView(
                        area: area,
                        tasks: tasksForArea(area),
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    )
                } else {
                    ContentUnavailableView("Area unavailable", systemImage: "rectangle.stack.badge.minus")
                }
            case .project(let id):
                if let project = projects.first(where: { $0.id == id }) {
                    FluxProjectDetailView(
                        project: project,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    )
                } else {
                    ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
                }
            }
        }
    }

    // MARK: - Data

    private var filteredAreas: [FluxArea] {
        guard !searchText.isEmpty else { return areas }
        return areas.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
                || filteredProjects(in: $0).isEmpty == false
        }
    }

    private func filteredProjects(in area: FluxArea) -> [FluxProject] {
        let areaProjects = projects.filter { $0.area?.id == area.id }
        guard !searchText.isEmpty else { return areaProjects }
        return areaProjects.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var searchResults: [FluxTask] {
        tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
                || ($0.area?.title.localizedCaseInsensitiveContains(searchText) ?? false)
                || ($0.project?.title.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.tags.contains(where: { $0.title.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var inboxTasks: [FluxTask] { activeTasks.filter(\.isInInbox) }
    private var todayTasks: [FluxTask] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && !$0.isEvening
        }
    }
    private var eveningTasks: [FluxTask] {
        let start = Calendar.current.startOfDay(for: .now)
        return activeTasks.filter {
            guard let date = $0.whenDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: start) && $0.isEvening
        }
    }
    private var upcomingTasks: [FluxTask] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        return activeTasks.filter {
            guard let date = $0.effectiveDate else { return false }
            return date >= tomorrow
        }
    }
    private var anytimeTasks: [FluxTask] { activeTasks.filter { !$0.isInInbox && $0.whenDate == nil } }
    private var somedayTasks: [FluxTask] { tasks.filter { $0.status == .someday } }
    private var logbookTasks: [FluxTask] {
        tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    private var activeTasks: [FluxTask] { tasks.filter { $0.status == .active } }

    private var selectedProjectID: UUID? {
        if case .project(let id) = selection { return id }
        return nil
    }

    private func tasksForArea(_ area: FluxArea) -> [FluxTask] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }

    // MARK: - Actions

    private func toggleTask(_ task: FluxTask) {
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

    private func reassign(tasks ids: [String], to area: FluxArea) -> Bool {
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

    private func reassign(tasks ids: [String], to project: FluxProject, in area: FluxArea) -> Bool {
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

    private func navLink(_ title: String, systemImage: String, selection: FluxSidebarSelection, count: Int) -> some View {
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

// MARK: - Task Collection View

private struct FluxTaskCollectionView: View {
    let title: String
    let tasks: [FluxTask]
    var eveningTasks: [FluxTask] = []
    let events: [FluxCalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (FluxTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FluxHeaderCard(title: title)

                if !events.isEmpty {
                    FluxEventStrip(events: events)
                }

                if tasks.isEmpty && eveningTasks.isEmpty {
                    FluxEmptyState(title: title)
                } else {
                    FluxTaskSection(
                        title: "Tasks",
                        tasks: tasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs,
                        onToggle: onToggle
                    )
                    if !eveningTasks.isEmpty {
                        FluxTaskSection(
                            title: "This Evening",
                            tasks: eveningTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs,
                            onToggle: onToggle
                        )
                    }
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Area Detail View

struct FluxAreaDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let area: FluxArea
    let tasks: [FluxTask]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FluxHeaderCard(title: area.title)

                ForEach(area.projects.sorted(by: { $0.sortOrder < $1.sortOrder })) { project in
                    FluxProjectCard(project: project)
                }

                FluxTaskSection(
                    title: "Area tasks",
                    tasks: tasks.filter { $0.project == nil },
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs
                ) { task in
                    if task.isCompleted { task.reopen() } else { task.markComplete() }
                    try? modelContext.save()
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Project Detail View

struct FluxProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let project: FluxProject
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @State private var newHeadingTitle = ""
    @State private var showAddHeading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.title)
                            .font(.system(size: 32, weight: .bold))

                        if !project.goalSummary.isEmpty {
                            Text(project.goalSummary)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Simple notes editor
                TextEditor(text: Binding(
                    get: { project.notes },
                    set: {
                        project.notes = $0
                        try? modelContext.save()
                    }
                ))
                .font(.body)
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 40)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if project.notes.isEmpty {
                        Text("Notes…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .padding(.top, 2)
                            .allowsHitTesting(false)
                    }
                }

                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id }
                    FluxTaskSection(
                        title: heading.title,
                        tasks: headingTasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    ) { task in
                        if task.isCompleted { task.reopen() } else { task.markComplete() }
                        try? modelContext.save()
                    }
                }

                let ungroupedTasks = project.sortedTasks.filter { $0.heading == nil }
                if !ungroupedTasks.isEmpty {
                    FluxTaskSection(
                        title: "Tasks",
                        tasks: ungroupedTasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs
                    ) { task in
                        if task.isCompleted { task.reopen() } else { task.markComplete() }
                        try? modelContext.save()
                    }
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
    }

    private func addHeading() {
        let title = newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let heading = FluxHeading(
            title: title,
            sortOrder: Double(project.headings.count),
            project: project
        )
        modelContext.insert(heading)
        try? modelContext.save()
        newHeadingTitle = ""
        showAddHeading = false
    }
}

// MARK: - Header Card

private struct FluxHeaderCard: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

// MARK: - Project Card

private struct FluxProjectCard: View {
    let project: FluxProject

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                Text(project.goalSummary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(project.activeTaskCount) active")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Task Section

private struct FluxTaskSection: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let tasks: [FluxTask]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (FluxTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tasks.count)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    FluxTaskRow(
                        task: task,
                        isExpanded: expandedTaskID == task.id,
                        isCompleting: completingTaskIDs.contains(task.id),
                        onToggle: { onToggle(task) },
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                expandedTaskID = expandedTaskID == task.id ? nil : task.id
                            }
                        },
                        onDelete: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                if expandedTaskID == task.id { expandedTaskID = nil }
                                completingTaskIDs.remove(task.id)
                                modelContext.delete(task)
                                try? modelContext.save()
                            }
                        }
                    )
                    if task.id != tasks.last?.id {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

// MARK: - Task Row

private enum TaskActionMode: Hashable {
    case calendar
    case tags
    case subtasks
    case deadline
}

private struct FluxTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    let task: FluxTask
    let isExpanded: Bool
    let isCompleting: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    var onDelete: (() -> Void)?

    @State private var activeAction: TaskActionMode?
    @State private var showTagsPopover = false
    @State private var newSubtaskTitle = ""

    private var isDone: Bool { isCompleting || task.isCompleted }

    private var hasCompactMeta: Bool {
        task.project != nil || task.area != nil || !task.tags.isEmpty
            || task.effectiveDate != nil || !task.checklist.isEmpty
            || task.recurrenceRule != nil || task.deadline != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row: checkbox + title
            HStack(alignment: hasCompactMeta && !isExpanded ? .top : .center, spacing: 14) {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)

                    // Collapsed inline meta
                    if !isExpanded && hasCompactMeta {
                        compactMeta
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .opacity(isCompleting ? 0.5 : 1.0)

            // Expanded
            if isExpanded {
                expandedContent
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }

            Divider()

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
        .draggable(task.id.uuidString)
    }

    // MARK: Collapsed meta badges

    private var compactMeta: some View {
        HStack(spacing: 6) {
            if let project = task.project {
                FluxBadge(text: project.title, tint: project.tintHex)
            } else if let area = task.area {
                FluxBadge(text: area.title, tint: area.tintHex)
            }

            ForEach(task.tags.prefix(3)) { tag in
                FluxBadge(text: tag.title, tint: tag.tintHex)
            }

            if let date = task.whenDate {
                FluxDateBadge(date: date, isDeadline: false)
            }

            if let deadline = task.deadline {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text(deadline.formatted(.dateTime.month(.abbreviated).day()))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: Capsule())
            }

            if !task.checklist.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(task.checklist.filter(\.isCompleted).count)/\(task.checklist.count)")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.06), in: Capsule())
            }

            if task.recurrenceRule != nil {
                Image(systemName: "repeat")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tag badges — directly under title
            if !task.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(task.tags) { tag in
                        HStack(spacing: 4) {
                            Text(tag.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: tag.tintHex))
                            Button {
                                task.tags.removeAll { $0.id == tag.id }
                                task.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: tag.tintHex).opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: tag.tintHex).opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 4)
            }

            // Notes - editable
            ZStack(alignment: .topLeading) {
                if task.notes.isEmpty {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { task.notes },
                    set: {
                        task.notes = $0
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 36)
            }
            .padding(.horizontal, 56)

            // Subtasks section
            if !task.checklist.isEmpty || activeAction == .subtasks {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtasks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 56)
                        .padding(.top, 14)

                    if !task.checklist.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(task.checklist.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                                FluxChecklistRow(item: item)
                            }
                        }
                        .padding(.horizontal, 38)
                    }

                    // Add subtask inline
                    if activeAction == .subtasks {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)

                            TextField("Add subtask…", text: $newSubtaskTitle)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(.horizontal, 56)
                        .padding(.top, 2)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 4)
            }

            // Bottom bar: breadcrumb on left, action buttons on right
            HStack(spacing: 0) {
                // Left: breadcrumb
                if let area = task.area {
                    HStack(spacing: 5) {
                        Image(systemName: area.symbolName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: area.tintHex))
                        Text(area.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: area.tintHex))

                        if let project = task.project {
                            Text("›")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                            Text(project.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Date / evening badge
                dateLabel
                    .font(.caption.weight(.medium))

                Spacer()
                    .frame(maxWidth: 16)

                // Right: action buttons
                HStack(spacing: 2) {
                    actionButton(.calendar, icon: "calendar", filledIcon: "calendar.circle.fill", active: task.whenDate != nil)

                    // Tags as popover
                    Button {
                        showTagsPopover.toggle()
                    } label: {
                        Image(systemName: !task.tags.isEmpty ? "tag.fill" : "tag")
                            .font(.system(size: 14))
                            .foregroundStyle(showTagsPopover ? .primary : (!task.tags.isEmpty ? .primary : .secondary))
                            .frame(width: 30, height: 28)
                            .background(showTagsPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTagsPopover, arrowEdge: .bottom) {
                        FluxTagPanel(task: task)
                            .frame(width: 220)
                            .padding(4)
                    }

                    actionButton(.subtasks, icon: "checklist", filledIcon: "checklist.checked", active: !task.checklist.isEmpty)
                    actionButton(.deadline, icon: "flag", filledIcon: "flag.fill", active: task.deadline != nil)
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Expanded action panel (calendar/deadline — subtasks panel is inline above)
            if let action = activeAction, action != .subtasks {
                actionPanel(for: action)
                    .padding(.horizontal, 56)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dateLabel: some View {
        if let date = task.whenDate {
            if task.isEvening {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo)
                    Text("This Evening")
                        .foregroundStyle(.indigo)
                }
            } else if Calendar.current.isDateInToday(date) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text("Today")
                        .foregroundStyle(.primary)
                }
            } else {
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .foregroundStyle(.secondary)
            }
        } else if task.isEvening {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.indigo)
                Text("This Evening")
                    .foregroundStyle(.indigo)
            }
        } else {
            Text("")
        }
    }

    private func actionButton(_ mode: TaskActionMode, icon: String, filledIcon: String, active: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeAction = activeAction == mode ? nil : mode
            }
        } label: {
            Image(systemName: active ? filledIcon : icon)
                .font(.system(size: 14))
                .foregroundStyle(activeAction == mode ? .primary : (active ? .primary : .secondary))
                .frame(width: 30, height: 28)
                .background(activeAction == mode ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: Action panels

    @ViewBuilder
    private func actionPanel(for action: TaskActionMode) -> some View {
        switch action {
        case .calendar:
            calendarPanel
        case .tags:
            EmptyView()
        case .subtasks:
            EmptyView()
        case .deadline:
            deadlinePanel
        }
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick-pick buttons
            HStack(spacing: 8) {
                calendarQuickButton(icon: "star.fill", iconColor: .yellow, label: "Today") {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                calendarQuickButton(icon: "moon.fill", iconColor: .indigo, label: "Evening") {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = true
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                calendarQuickButton(icon: "shippingbox", iconColor: .secondary, label: "Someday") {
                    task.status = .someday
                    task.whenDate = nil
                    task.updatedAt = .now
                    try? modelContext.save()
                }

                if task.whenDate != nil {
                    calendarQuickButton(icon: "xmark", iconColor: .secondary, label: "Clear") {
                        task.whenDate = nil
                        task.isEvening = false
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
            }

            // Calendar grid
            FluxCalendarGrid(
                selectedDate: task.whenDate,
                onSelect: { date in
                    task.whenDate = date
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func calendarQuickButton(icon: String, iconColor: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, height: 48)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("Deadline")
                    .font(.subheadline.weight(.medium))

                Spacer()

                if task.deadline != nil {
                    Button {
                        task.deadline = nil
                        task.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            FluxCalendarGrid(
                selectedDate: task.deadline,
                accentColor: .orange,
                onSelect: { date in
                    task.deadline = date
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let item = FluxChecklistItem(
            title: title,
            sortOrder: Double(task.checklist.count),
            task: task
        )
        modelContext.insert(item)
        task.checklist.append(item)
        try? modelContext.save()
        newSubtaskTitle = ""
    }
}

// MARK: - Tag Panel

private struct FluxTagPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FluxTag.title) private var allTags: [FluxTag]
    let task: FluxTask

    @State private var searchText = ""

    private var filteredTags: [FluxTag] {
        let unassigned = allTags.filter { tag in
            !task.tags.contains(where: { $0.id == tag.id })
        }
        if searchText.isEmpty { return unassigned }
        return unassigned.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Tags", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit {
                        createTag()
                    }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !filteredTags.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTags.prefix(6)) { tag in
                        Button {
                            task.tags.append(tag)
                            task.updatedAt = .now
                            try? modelContext.save()
                            searchText = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: tag.tintHex))
                                Text(tag.title)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func createTag() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = FluxTag(title: name)
        modelContext.insert(tag)
        task.tags.append(tag)
        task.updatedAt = .now
        try? modelContext.save()
        searchText = ""
    }
}

// MARK: - Checklist Row

private struct FluxChecklistRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: FluxChecklistItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    item.isCompleted.toggle()
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(item.isCompleted ? Color.green : Color.gray.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.subheadline)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Calendar Grid

private struct FluxCalendarGrid: View {
    let selectedDate: Date?
    var accentColor: Color = .blue
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayOfWeekSymbols = Calendar.current.shortWeekdaySymbols

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInGrid: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = weekdayOfFirst - calendar.firstWeekday
        let adjustedBlanks = (leadingBlanks + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: adjustedBlanks)
        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: sel)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Month header with navigation
            HStack {
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(dayOfWeekSymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(height: 20)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            onSelect(date)
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: isSelected(date) ? .semibold : .regular))
                                .foregroundStyle(isSelected(date) ? .white : (isToday(date) ? accentColor : .primary))
                                .frame(width: 32, height: 32)
                                .background {
                                    if isSelected(date) {
                                        Circle().fill(accentColor)
                                    } else if isToday(date) {
                                        Circle().fill(accentColor.opacity(0.1))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }
}

// MARK: - Badges

private struct FluxBadge: View {
    let text: String
    let tint: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(hex: tint))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: tint).opacity(0.12), in: Capsule())
    }
}

private struct FluxDateBadge: View {
    let date: Date
    let isDeadline: Bool

    var body: some View {
        Text(date.formatted(.dateTime.month(.abbreviated).day()))
            .font(.caption.weight(.medium))
            .foregroundStyle(isDeadline ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(isDeadline ? 0.10 : 0.06), in: Capsule())
    }
}

// MARK: - Event Strip

private struct FluxEventStrip: View {
    let events: [FluxCalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar")
                .font(.headline)

            ForEach(events) { event in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.medium))
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

// MARK: - Empty State

private struct FluxEmptyState: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing in \(title.lowercased()) right now.")
                .font(.title3.weight(.semibold))
            Text("Use Quick Entry to capture something new, or drag tasks in from another project or area.")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var tintHex = "#2E6BC6"

    private let tintOptions = ["#2E6BC6", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#5B83B7"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Project")
                .font(.title2.weight(.semibold))

            TextField("Project name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Goal or description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            Picker("Area", selection: $selectedAreaID) {
                Text("No area").tag(UUID?.none)
                ForEach(areas) { area in
                    Text(area.title).tag(Optional(area.id))
                }
            }

            HStack(spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                ForEach(tintOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if tintHex == hex {
                                Circle().stroke(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { tintHex = hex }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func createProject() {
        let area = areas.first(where: { $0.id == selectedAreaID })
        let project = FluxProject(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalSummary: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tintHex: tintHex,
            sortOrder: Double(areas.flatMap(\.projects).count),
            area: area
        )
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - New Area Sheet

struct NewAreaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]

    @State private var title = ""
    @State private var notes = ""
    @State private var symbolName = "square.grid.2x2"
    @State private var tintHex = "#5B83B7"

    private let symbolOptions = [
        "square.grid.2x2", "briefcase.fill", "heart.text.square.fill",
        "house.fill", "graduationcap.fill", "figure.run",
        "dollarsign.circle.fill", "paintbrush.fill"
    ]
    private let tintOptions = ["#5B83B7", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#2E6BC6"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Area")
                .font(.title2.weight(.semibold))

            TextField("Area name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text("Icon")
                    .font(.subheadline.weight(.medium))
                ForEach(symbolOptions, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(symbolName == symbol ? Color(hex: tintHex) : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            symbolName == symbol
                                ? Color(hex: tintHex).opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .onTapGesture { symbolName = symbol }
                }
            }

            HStack(spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                ForEach(tintOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if tintHex == hex {
                                Circle().stroke(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { tintHex = hex }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createArea()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func createArea() {
        let area = FluxArea(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            tintHex: tintHex,
            sortOrder: Double(areas.count)
        )
        modelContext.insert(area)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fluxShowCompletedTasks") private var showCompleted = false
    @AppStorage("fluxDefaultView") private var defaultView = "inbox"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show completed tasks in lists", isOn: $showCompleted)

                    Picker("Default view", selection: $defaultView) {
                        Text("Inbox").tag("inbox")
                        Text("Today").tag("today")
                        Text("Upcoming").tag("upcoming")
                        Text("Anytime").tag("anytime")
                    }
                }
                .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}

// MARK: - Supporting Types

private struct SelectedProjectIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var selectedProjectID: UUID? {
        get { self[SelectedProjectIDKey.self] }
        set { self[SelectedProjectIDKey.self] = newValue }
    }
}

// MARK: - Flow Layout (for tag chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
