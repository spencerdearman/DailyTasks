//
//  ContentView.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - ContentView

/// The root sidebar view displaying core lists, areas, and projects.
struct ContentView: View {

    // MARK: - Queries

    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    // MARK: - State

    @State private var quickEntrySelection: SidebarSelection?
    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var overlayMode: OverlayMode = .none
    @State private var showSettings = false
    @State private var quickFindPath: [SidebarSelection] = []

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $quickFindPath) {
            List {
                Section("Core") {
                    coreLink("Inbox", systemImage: "tray.fill", selection: .inbox, count: inboxTasks.count)
                    coreLink("Today", systemImage: "sun.max.fill", selection: .today, count: todayTasks.count)
                    coreLink("Upcoming", systemImage: "calendar", selection: .upcoming, count: upcomingTasks.count)
                    coreLink("Open", systemImage: "tray.2.fill", selection: .anytime, count: anytimeTasks.count)
                    coreLink("Later", systemImage: "moon.zzz.fill", selection: .someday, count: somedayTasks.count)
                    coreLink("Done", systemImage: "checkmark.circle.fill", selection: .logbook, count: logbookTasks.count)
                }

                Section("Areas") {
                    ForEach(filteredAreas) { area in
                        NavigationLink(value: SidebarSelection.area(area.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: area.symbolName)
                                    .foregroundStyle(Color(hex: area.tintHex))
                                    .frame(width: 18)
                                Text(area.title)
                                Spacer()
                                Text("\(area.activeTaskCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(filteredProjects(in: area)) { project in
                            NavigationLink(value: SidebarSelection.project(project.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "paperplane")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                    Text(project.title)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(project.activeTaskCount)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .pullToAgent()
            .navigationTitle("Flux")
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            quickEntrySelection = .inbox
                            showingQuickEntry = true
                        } label: {
                            Label("New Task", systemImage: "checkmark.circle")
                        }
                        Button {
                            showingNewProject = true
                        } label: {
                            Label("New Project", systemImage: "paperplane")
                        }
                        Button {
                            showingNewArea = true
                        } label: {
                            Label("New Area", systemImage: "square.grid.2x2")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntrySheet(defaultSelection: quickEntrySelection)
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectSheet()
            }
            .sheet(isPresented: $showingNewArea) {
                NewAreaSheet()
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .navigationDestination(for: SidebarSelection.self) { selection in
                destination(for: selection)
            }
        }
        .tint(.primary)
        .environment(\.overlayMode, $overlayMode)
        .overlay {
            if overlayMode != .none {
                CommandPaletteOverlay(
                    mode: $overlayMode,
                    areas: areas,
                    projects: projects,
                    tasks: tasks,
                    onSelectSidebar: { sel in
                        overlayMode = .none
                        quickFindPath = [sel]
                    },
                    onSelectTask: { task in
                        overlayMode = .none
                        if let project = task.project {
                            quickFindPath = [.project(project.id)]
                        } else if let area = task.area {
                            quickFindPath = [.area(area.id)]
                        } else if task.isInInbox {
                            quickFindPath = [.inbox]
                        }
                    }
                )
            }
        }
    }

    // MARK: - Sidebar Helpers

    private func coreLink(_ title: String, systemImage: String, selection: SidebarSelection, count: Int) -> some View {
        NavigationLink(value: selection) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destination(for selection: SidebarSelection) -> some View {
        switch selection {
            case .inbox:
                TaskListScreen(title: "Inbox", tasks: inboxTasks, defaultSelection: .inbox)
            case .today:
                TaskListScreen(title: "Today", tasks: todayTasks + eveningTasks, defaultSelection: .today)
            case .upcoming:
                TaskListScreen(title: "Upcoming", tasks: upcomingTasks, defaultSelection: .upcoming)
            case .anytime:
                TaskListScreen(title: "Open", tasks: anytimeTasks, defaultSelection: .anytime)
            case .someday:
                TaskListScreen(title: "Later", tasks: somedayTasks, defaultSelection: .someday)
            case .logbook:
                TaskListScreen(title: "Done", tasks: logbookTasks, defaultSelection: .logbook)
            case .area(let id):
                if let area = areas.first(where: { $0.id == id }) {
                    AreaScreen(area: area, tasks: tasksForArea(area))
                } else {
                    ContentUnavailableView("Area unavailable", systemImage: "rectangle.stack.badge.minus")
                }
            case .project(let id):
                if let project = projects.first(where: { $0.id == id }) {
                    ProjectScreen(project: project)
                } else {
                    ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
                }
        }
    }

    // MARK: - Filtered Data

    private var filteredAreas: [Area] { areas }

    private func filteredProjects(in area: Area) -> [Project] {
        projects.filter { $0.area?.id == area.id }
    }

    // MARK: - Task Filters

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

    private func tasksForArea(_ area: Area) -> [TaskItem] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }
}

// MARK: - Overlay Mode

enum OverlayMode: Equatable {
    case none
    case find
    case agent
}

// MARK: - Environment Key

private struct OverlayModeKey: EnvironmentKey {
    static let defaultValue: Binding<OverlayMode> = .constant(.none)
}

extension EnvironmentValues {
    var overlayMode: Binding<OverlayMode> {
        get { self[OverlayModeKey.self] }
        set { self[OverlayModeKey.self] = newValue }
    }
}

// MARK: - PullToAgent

/// A view modifier with a single pull gesture: pull down past threshold → Agent.
struct PullToAgent: ViewModifier {

    @Environment(\.overlayMode) private var overlayMode

    @State private var pullOffset: CGFloat = 0
    @State private var hitThreshold = false

    private let threshold: CGFloat = 80

    private var progress: CGFloat {
        guard pullOffset > 0 else { return 0 }
        return min(pullOffset / threshold, 1)
    }

    func body(content: Content) -> some View {
        GeometryReader { _ in
            content
                .overlay(alignment: .top) {
                    if pullOffset > 15 {
                        pullIndicator
                            .frame(height: 50)
                            .offset(y: min(pullOffset * 0.3, 40) - 45)
                            .opacity(min(pullOffset / 40, 1.0))
                            .animation(.easeOut(duration: 0.12), value: pullOffset)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, newValue in
                    pullOffset = max(0, -newValue)
                }
                .onChange(of: pullOffset) { oldValue, newValue in
                    handlePullChange(old: oldValue, new: newValue)
                }
        }
    }

    // MARK: - Pull Indicator

    private var pullIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(progress >= 1 ? Color.purple.opacity(0.8) : Color.secondary)
                .scaleEffect(0.6 + progress * 0.4)

            if progress > 0.5 {
                Text(progress >= 1 ? "Release for Agent" : "Pull for Agent")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(progress >= 1 ? Color.purple.opacity(0.8) : Color.secondary)
            }
        }
    }

    // MARK: - Haptic & Trigger Logic

    private func handlePullChange(old: CGFloat, new: CGFloat) {
        if new >= threshold && old < threshold && !hitThreshold {
            hitThreshold = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if new < threshold * 0.7 {
            hitThreshold = false
        }

        let isReleasing = old > new && new < old * 0.85

        if isReleasing && old >= threshold {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            overlayMode.wrappedValue = .agent
        }
    }
}

extension View {
    /// Adds a pull-down gesture that opens the Agent overlay.
    func pullToAgent() -> some View {
        modifier(PullToAgent())
    }
}
