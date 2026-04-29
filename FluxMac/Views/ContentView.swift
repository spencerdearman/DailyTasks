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
                navLink("Anytime", systemImage: "square.stack.3d.up.fill", selection: .anytime, count: anytimeTasks.count)
                navLink("Someday", systemImage: "shippingbox.fill", selection: .someday, count: somedayTasks.count)
                navLink("Logbook", systemImage: "checkmark.square.fill", selection: .logbook, count: logbookTasks.count)
            }

            Section("Areas") {
                ForEach(filteredAreas) { area in
                    DisclosureGroup {
                        ForEach(filteredProjects(in: area)) { project in
                            NavigationLink(value: FluxSidebarSelection.project(project.id)) {
                                HStack(spacing: 10) {
                                    FluxProgressPie(progress: project.completionRatio, tint: project.tintHex)
                                        .frame(width: 16, height: 16)
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
                HStack(spacing: 28) {
                    detailFooterButton(systemImage: "plus") {
                        showQuickEntrySheet = true
                    }
                    detailFooterButton(systemImage: "calendar") {}
                    detailFooterButton(systemImage: "arrow.down.circle") {
                        calendarStore.importReminders(into: modelContext, areas: areas)
                    }
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
                .padding(.horizontal, 26)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 10)
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        if !searchText.isEmpty {
            FluxTaskCollectionView(
                title: "Search",
                subtitle: "Jump quickly between tasks, areas, and projects as you type.",
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
                    subtitle: "The landing zone for everything new before it gets organized.",
                    tasks: inboxTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .today:
                FluxTaskCollectionView(
                    title: "Today",
                    subtitle: "Tasks scheduled for now, plus a dedicated evening lane.",
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
                    subtitle: "A longer runway for deadlines, scheduled work, and next-week planning.",
                    tasks: upcomingTasks,
                    events: calendarStore.upcomingEvents,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .anytime:
                FluxTaskCollectionView(
                    title: "Anytime",
                    subtitle: "Active work without a date attached yet.",
                    tasks: anytimeTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .someday:
                FluxTaskCollectionView(
                    title: "Someday",
                    subtitle: "Ideas and long-burn possibilities that should stay visible but calm.",
                    tasks: somedayTasks,
                    events: [],
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs,
                    onToggle: toggleTask
                )
            case .logbook:
                FluxTaskCollectionView(
                    title: "Logbook",
                    subtitle: "Everything you have completed, ordered by completion date.",
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

    private func detailFooterButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Collection View

private struct FluxTaskCollectionView: View {
    let title: String
    let subtitle: String
    let tasks: [FluxTask]
    var eveningTasks: [FluxTask] = []
    let events: [FluxCalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (FluxTask) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FluxHeaderCard(title: title, subtitle: subtitle)

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
                FluxHeaderCard(title: area.title, subtitle: area.notes)

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
    @State private var noteMode: NoteMode = .preview
    @State private var newHeadingTitle = ""
    @State private var showAddHeading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    FluxProgressPie(progress: project.completionRatio, tint: project.tintHex, lineWidth: 10)
                        .frame(width: 64, height: 64)

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

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Notes Mode", selection: $noteMode) {
                        ForEach(NoteMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)

                    if noteMode == .edit {
                        TextEditor(text: Binding(
                            get: { project.notes },
                            set: {
                                project.notes = $0
                                try? modelContext.save()
                            }
                        ))
                        .font(.body)
                        .frame(minHeight: 180)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        ScrollView {
                            Text(.init(project.notes.isEmpty ? "No notes yet." : project.notes))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                        }
                        .frame(minHeight: 180)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
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
            FluxProgressPie(progress: project.completionRatio, tint: project.tintHex)
                .frame(width: 26, height: 26)
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

    @State private var activeAction: TaskActionMode?
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
            // Notes - editable
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
            .frame(minHeight: 36, maxHeight: 80)
            .padding(.horizontal, 56)
            .overlay(alignment: .topLeading) {
                if task.notes.isEmpty {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 56)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }

            // Tag badges (if any)
            if !task.tags.isEmpty {
                HStack(spacing: 6) {
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
                .padding(.top, 8)
            }

            // Existing subtasks
            if !task.checklist.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.checklist.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                        FluxChecklistRow(item: item)
                    }
                }
                .padding(.horizontal, 38)
                .padding(.top, 10)
            }

            // Action bar: date/evening on left, 4 icon buttons on right
            HStack(spacing: 0) {
                // Left: date/evening info
                dateLabel
                    .font(.subheadline)

                Spacer()

                // Right: 4 action buttons
                HStack(spacing: 2) {
                    actionButton(.calendar, icon: "calendar", active: task.whenDate != nil)
                    actionButton(.tags, icon: "tag", active: !task.tags.isEmpty)
                    actionButton(.subtasks, icon: "list.bullet", active: !task.checklist.isEmpty)
                    actionButton(.deadline, icon: "flag", active: task.deadline != nil)
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Expanded action panel
            if let action = activeAction {
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

    private func actionButton(_ mode: TaskActionMode, icon: String, active: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeAction = activeAction == mode ? nil : mode
            }
        } label: {
            Image(systemName: active ? "\(icon).fill" : icon)
                .font(.system(size: 14))
                .foregroundStyle(activeAction == mode ? .primary : (active ? .primary : .tertiary))
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
            tagsPanel
        case .subtasks:
            subtasksPanel
        case .deadline:
            deadlinePanel
        }
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow)
                        Text("Today").font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = true
                    task.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.indigo)
                        Text("This Evening").font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    task.status = .someday
                    task.whenDate = nil
                    task.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox").font(.system(size: 11))
                        Text("Someday").font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                if task.whenDate != nil {
                    Button {
                        task.whenDate = nil
                        task.isEvening = false
                        task.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            DatePicker("", selection: Binding(
                get: { task.whenDate ?? .now },
                set: {
                    task.whenDate = $0
                    task.isEvening = false
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            ), displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: 280, maxHeight: 240)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tagsPanel: some View {
        FluxTagPanel(task: task)
    }

    private var subtasksPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Add subtask…", text: $newSubtaskTitle)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onSubmit {
                    addSubtask()
                }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if task.deadline != nil {
                HStack(spacing: 8) {
                    Text("Due \(task.deadline!.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Button {
                        task.deadline = nil
                        task.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            DatePicker("", selection: Binding(
                get: { task.deadline ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now },
                set: {
                    task.deadline = $0
                    task.updatedAt = .now
                    try? modelContext.save()
                }
            ), displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: 280, maxHeight: 240)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

// MARK: - Progress Pie

struct FluxProgressPie: View {
    let progress: Double
    let tint: String
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: tint).opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(hex: tint),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
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

private enum NoteMode: String, CaseIterable, Identifiable {
    case preview
    case edit

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct SelectedProjectIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var selectedProjectID: UUID? {
        get { self[SelectedProjectIDKey.self] }
        set { self[SelectedProjectIDKey.self] = newValue }
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
