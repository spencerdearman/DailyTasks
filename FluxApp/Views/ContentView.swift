import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @State private var quickEntrySelection: SidebarSelection?
    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var showQuickFind = false
    @State private var quickFindPath: [SidebarSelection] = []

    var body: some View {
        NavigationStack(path: $quickFindPath) {
            List {
                Button {
                    showQuickFind = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Quick Find")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
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
            .navigationDestination(for: SidebarSelection.self) { selection in
                destination(for: selection)
            }
        }
        .tint(.primary)
        .environment(\.showQuickFind, $showQuickFind)
        .overlay {
            if showQuickFind {
                QuickFindOverlay(
                    areas: areas,
                    projects: projects,
                    tasks: tasks,
                    onSelectSidebar: { sel in
                        showQuickFind = false
                        quickFindPath = [sel]
                    },
                    onSelectTask: { task in
                        showQuickFind = false
                        if let project = task.project {
                            quickFindPath = [.project(project.id)]
                        } else if let area = task.area {
                            quickFindPath = [.area(area.id)]
                        } else if task.isInInbox {
                            quickFindPath = [.inbox]
                        }
                    },
                    onDismiss: {
                        showQuickFind = false
                    }
                )
            }
        }
    }

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

    private func tasksForArea(_ area: Area) -> [TaskItem] {
        tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
            .sorted { ($0.effectiveDate ?? .distantFuture) < ($1.effectiveDate ?? .distantFuture) }
    }
}

// MARK: - Environment key for Quick Find

private struct ShowQuickFindKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var showQuickFind: Binding<Bool> {
        get { self[ShowQuickFindKey.self] }
        set { self[ShowQuickFindKey.self] = newValue }
    }
}

// MARK: - Pull-down Quick Find modifier

struct PullToQuickFind: ViewModifier {
    @Environment(\.showQuickFind) private var showQuickFind
    @State private var pullOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    private let threshold: CGFloat = 140

    func body(content: Content) -> some View {
        GeometryReader { outer in
            content
                .overlay(alignment: .top) {
                    if pullOffset > 20 {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                                .scaleEffect(min(pullOffset / threshold, 1.0))
                                .rotationEffect(.degrees(pullOffset >= threshold ? 0 : -90 * (1 - pullOffset / threshold)))
                            if pullOffset > threshold * 0.5 {
                                Text(pullOffset >= threshold ? "Release to search" : "Pull to search")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .frame(height: 50)
                        .offset(y: min(pullOffset * 0.35, 50) - 50)
                        .opacity(min(pullOffset / 50, 1.0))
                        .animation(.easeOut(duration: 0.15), value: pullOffset)
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, newValue in
                    pullOffset = max(0, -newValue)
                }
                .onChange(of: pullOffset) { oldValue, newValue in
                    // First haptic when crossing threshold going down
                    if newValue >= threshold && !hasTriggeredHaptic {
                        hasTriggeredHaptic = true
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    // Reset haptic flag when pulling back up
                    if newValue < threshold * 0.8 {
                        hasTriggeredHaptic = false
                    }
                    // Trigger Quick Find when user releases past threshold
                    if oldValue >= threshold && newValue < threshold && oldValue > newValue {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        showQuickFind.wrappedValue = true
                    }
                }
        }
    }
}

extension View {
    func pullToQuickFind() -> some View {
        modifier(PullToQuickFind())
    }
}
