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
                Button {
                    overlayMode = .find
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text("Find")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

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
            .navigationTitle("Flux")
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        overlayMode = .agent
                    } label: {
                        Label("Agent", systemImage: "sparkles")
                    }
                }

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

// MARK: - PullToQuickFind (Dual-Depth)

/// A view modifier with a dual-depth pull gesture:
/// - Shallow pull (past ~80pt) → Quick Find search
/// - Deep pull (past ~160pt) → Agent AI chat
/// The icon morphs from magnifying glass to sparkle during transition.
struct PullToQuickFind: ViewModifier {

    @Environment(\.overlayMode) private var overlayMode

    @State private var pullOffset: CGFloat = 0
    @State private var hitShallow = false
    @State private var hitDeep = false

    private let shallowThreshold: CGFloat = 80
    private let deepThreshold: CGFloat = 160

    /// 0 = not pulling, 0..1 = approaching shallow, 1 = at shallow, 1..2 = approaching deep, 2 = at deep
    private var depthProgress: CGFloat {
        if pullOffset <= 0 { return 0 }
        if pullOffset <= shallowThreshold {
            return pullOffset / shallowThreshold
        }
        let extra = pullOffset - shallowThreshold
        let gap = deepThreshold - shallowThreshold
        return 1 + min(extra / gap, 1)
    }

    private var isInDeepZone: Bool { depthProgress >= 2.0 }

    func body(content: Content) -> some View {
        GeometryReader { _ in
            content
                .overlay(alignment: .top) {
                    if pullOffset > 15 {
                        pullIndicator
                            .frame(height: 60)
                            .offset(y: min(pullOffset * 0.3, 50) - 55)
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
        let iconProgress = min(max((depthProgress - 1) / 1, 0), 1) // 0 at shallow, 1 at deep
        let scale = min(depthProgress, 1.0)

        return VStack(spacing: 5) {
            ZStack {
                // Magnifying glass — fades out as we enter deep zone
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(1 - iconProgress)
                    .scaleEffect(1 - iconProgress * 0.3)

                // Sparkle — fades in as we enter deep zone
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.purple.opacity(0.8))
                    .opacity(iconProgress)
                    .scaleEffect(0.5 + iconProgress * 0.5)
            }
            .scaleEffect(scale)

            Text(pullHintText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isInDeepZone ? .purple.opacity(0.8) : .secondary)
                .opacity(depthProgress > 0.5 ? 1 : 0)
                .animation(.easeOut(duration: 0.1), value: pullHintText)
        }
    }

    private var pullHintText: String {
        if depthProgress < 1 { return "Pull to search" }
        if depthProgress >= 1 && depthProgress < 2 { return "Release to search · keep pulling for Agent" }
        return "Release for Agent"
    }

    // MARK: - Haptic & Trigger Logic

    private func handlePullChange(old: CGFloat, new: CGFloat) {
        // Shallow haptic click
        if new >= shallowThreshold && old < shallowThreshold && !hitShallow {
            hitShallow = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        if new < shallowThreshold * 0.7 {
            hitShallow = false
        }

        // Deep haptic click
        if new >= deepThreshold && old < deepThreshold && !hitDeep {
            hitDeep = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        if new < deepThreshold * 0.8 {
            hitDeep = false
        }

        // Release detection: user let go (offset dropping quickly)
        let isReleasing = old > new && new < old * 0.85

        if isReleasing {
            if old >= deepThreshold {
                // Was in deep zone → open Agent
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                overlayMode.wrappedValue = .agent
            } else if old >= shallowThreshold {
                // Was in shallow zone → open Quick Find
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                overlayMode.wrappedValue = .find
            }
        }
    }
}

extension View {
    /// Adds a dual-depth pull gesture: shallow → search, deep → agent.
    func pullToQuickFind() -> some View {
        modifier(PullToQuickFind())
    }
}
