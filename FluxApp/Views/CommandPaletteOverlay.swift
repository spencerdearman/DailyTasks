//
//  CommandPaletteOverlay.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - CommandPaletteOverlay

/// A unified glass overlay that combines Find (search) and Agent (AI chat) in one panel.
/// Inspired by the macOS Flux overlay with tabbed Find / Agent modes.
struct CommandPaletteOverlay: View {

    // MARK: - Properties

    @Binding var mode: OverlayMode

    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let onSelectSidebar: (SidebarSelection) -> Void
    let onSelectTask: (TaskItem) -> Void

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @AppStorage("geminiAPIKey") private var apiKey = ""

    // MARK: - State

    @State private var showPanel = false
    @State private var findQuery = ""
    @State private var agentInput = ""
    @State private var agentResponses: [AgentResult] = []
    @State private var agent = TaskAgent()
    @State private var weatherService = FluxWeatherService()
    @State private var eventKitService = EventKitSyncService()
    @State private var isSynthesizing = false
    @State private var selectedTaskID: UUID?
    @FocusState private var isFindFocused: Bool
    @FocusState private var isAgentFocused: Bool

    // MARK: - Agent Result Model

    private struct AgentResult: Identifiable {
        let id = UUID()
        let query: String
        let text: String
        let taskCards: [AgentTaskCard]?
        let eventCards: [AgentEventCard]?
        let subtasks: [String]?
        let isPlanDay: Bool
        var synthesis: SynthesisData?
        let pendingDeletion: EventDeletion?

        init(query: String, text: String, taskCards: [AgentTaskCard]? = nil, eventCards: [AgentEventCard]? = nil, subtasks: [String]? = nil, isPlanDay: Bool = false, synthesis: SynthesisData? = nil, pendingDeletion: EventDeletion? = nil) {
            self.query = query
            self.text = text
            self.taskCards = taskCards
            self.eventCards = eventCards
            self.subtasks = subtasks
            self.isPlanDay = isPlanDay
            self.synthesis = synthesis
            self.pendingDeletion = pendingDeletion
        }
    }

    private struct SynthesisData {
        let greeting: String
        let conflicts: [String]
        let suggestedPlan: String
        let weatherSummary: String?
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(showPanel ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .animation(.easeOut(duration: 0.25), value: showPanel)

            // Panel
            VStack(spacing: 0) {
                tabBar

                Divider().opacity(0.4).padding(.horizontal, 12)

                // Content area
                if mode == .find {
                    findResults
                } else {
                    agentResults
                }

                Divider().opacity(0.3).padding(.horizontal, 12)

                // Input bar at bottom
                inputBar
            }
            .contentShape(Rectangle())
            .onTapGesture { /* absorb taps on panel so they don't dismiss */ }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            .scaleEffect(showPanel ? 1 : 0.95)
            .opacity(showPanel ? 1 : 0)
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showPanel = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if mode == .find {
                    isFindFocused = true
                } else {
                    isAgentFocused = true
                }
            }
        }
        .task {
            await weatherService.fetchWeather()
        }
        .sheet(item: selectedTaskBinding) { task in
            TaskEditorSheet(task: task)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabPill("Find", icon: "magnifyingglass", isActive: mode == .find) {
                withAnimation(.easeOut(duration: 0.2)) { mode = .find }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isFindFocused = true }
            }

            tabPill("Agent", icon: "sparkles", isActive: mode == .agent) {
                withAnimation(.easeOut(duration: 0.2)) { mode = .agent }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isAgentFocused = true }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func tabPill(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isActive ? .primary : .tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isActive ? Color.primary.opacity(0.1) : Color.clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unified Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: mode == .find ? "magnifyingglass" : "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, isActive: mode == .agent && (agent.isProcessing || isSynthesizing))

            if mode == .find {
                TextField("Search tasks, projects, areas...", text: $findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .light))
                    .focused($isFindFocused)
            } else {
                TextField("Ask Flux anything...", text: $agentInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .light))
                    .focused($isAgentFocused)
                    .onSubmit { submitAgent() }
            }

            // Trailing accessory
            if mode == .find && !findQuery.isEmpty {
                Button { findQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            } else if mode == .agent {
                if agent.isProcessing || isSynthesizing {
                    ProgressView()
                        .controlSize(.small)
                } else if !agentInput.isEmpty {
                    Button { submitAgent() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .find {
                isFindFocused = true
            } else {
                isAgentFocused = true
            }
        }
    }

    // MARK: - Find Results

    private var findResults: some View {
        Group {
            if findHasResults {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !findCoreListItems.isEmpty {
                            findSection("Lists", items: findCoreListItems)
                        }
                        if !findAreaItems.isEmpty {
                            findSection("Areas", items: findAreaItems)
                        }
                        if !findProjectItems.isEmpty {
                            findSection("Projects", items: findProjectItems)
                        }
                        if !findTaskItems.isEmpty {
                            findSection("Tasks", items: findTaskItems)
                        }
                        if findAllItems.isEmpty && !findQuery.isEmpty {
                            Text("No results")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: - Agent Results

    private var agentResults: some View {
        Group {
            if agentResponses.isEmpty && !agent.isProcessing && !isSynthesizing {
                agentEmptyState
            } else {
                agentResultsList
            }
        }
    }

    private var agentEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
                .padding(.top, 20)

            Text("Ask Flux anything")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                agentSuggestion("Plan my day")
                agentSuggestion("What's on my plate today?")
                agentSuggestion("Add a task to buy groceries")
            }
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func agentSuggestion(_ text: String) -> some View {
        Button {
            agentInput = text
            submitAgent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var agentResultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(agentResponses.enumerated()), id: \.element.id) { index, result in
                        if index > 0 {
                            Divider()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        }
                        agentResultView(result)
                            .id(result.id)
                    }

                    if agent.isProcessing || isSynthesizing {
                        ThinkingShimmer()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .id("thinking")
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 360)
            .onChange(of: agentResponses.count) {
                if let last = agentResponses.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Agent Result View

    private func agentResultView(_ result: AgentResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Query chip
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.quaternary)
                Text(result.query)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 4)

            // Text content
            let hasCards = result.taskCards != nil || result.eventCards != nil
            let displayText = cleanAgentMessage(result.text, hasCards: hasCards)

            if !displayText.isEmpty {
                Text(markdownString(displayText))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.bottom, hasCards ? 6 : 2)
            }

            // Task cards
            if let cards = result.taskCards, !cards.isEmpty {
                agentTaskList(cards)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }
        }
    }

    private func agentTaskList(_ cards: [AgentTaskCard]) -> some View {
        VStack(spacing: 0) {
            ForEach(cards.prefix(8)) { task in
                Button {
                    selectedTaskID = task.id
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(task.isCompleted ? .green : Color.primary.opacity(0.2))

                        Text(task.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        Spacer()

                        if let date = task.whenDate ?? task.deadline {
                            Text(shortDate(date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(date < Calendar.current.startOfDay(for: .now) ? .red : .secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Find Data

    private struct FindItem: Identifiable {
        let id: String
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String?
        let action: () -> Void
    }

    private var findCoreListItems: [FindItem] {
        let lists: [(String, String, Color, SidebarSelection)] = [
            ("Inbox", "tray.fill", .primary, .inbox),
            ("Today", "sun.max.fill", .yellow, .today),
            ("Upcoming", "calendar", .red, .upcoming),
            ("Open", "tray.2.fill", .blue, .anytime),
            ("Later", "moon.zzz.fill", .purple, .someday),
            ("Done", "checkmark.circle.fill", .green, .logbook),
        ]
        return lists.compactMap { (title, icon, color, sel) in
            guard findQuery.isEmpty || title.localizedCaseInsensitiveContains(findQuery) else { return nil }
            return FindItem(id: "list-\(title)", icon: icon, iconColor: color, title: title, subtitle: nil) {
                onSelectSidebar(sel)
            }
        }
    }

    private var findAreaItems: [FindItem] {
        let filtered = findQuery.isEmpty ? areas : areas.filter { $0.title.localizedCaseInsensitiveContains(findQuery) }
        return filtered.map { area in
            FindItem(id: "area-\(area.id)", icon: area.symbolName, iconColor: Color(hex: area.tintHex), title: area.title, subtitle: nil) {
                onSelectSidebar(.area(area.id))
            }
        }
    }

    private var findProjectItems: [FindItem] {
        let filtered = findQuery.isEmpty ? projects : projects.filter { $0.title.localizedCaseInsensitiveContains(findQuery) }
        return filtered.map { project in
            FindItem(id: "project-\(project.id)", icon: "paperplane", iconColor: Color(hex: project.tintHex), title: project.title, subtitle: project.area?.title) {
                onSelectSidebar(.project(project.id))
            }
        }
    }

    private var findTaskItems: [FindItem] {
        guard !findQuery.isEmpty else { return [] }
        let filtered = tasks.filter { !$0.isCompleted && $0.title.localizedCaseInsensitiveContains(findQuery) }
        return filtered.prefix(8).map { task in
            FindItem(id: "task-\(task.id)", icon: "circle", iconColor: .secondary, title: task.title, subtitle: task.project?.title ?? task.area?.title) {
                onSelectTask(task)
            }
        }
    }

    private var findAllItems: [FindItem] {
        findCoreListItems + findAreaItems + findProjectItems + findTaskItems
    }

    private var findHasResults: Bool {
        !findAllItems.isEmpty || !findQuery.isEmpty
    }

    private func findSection(_ title: String, items: [FindItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 3)

            ForEach(items) { item in
                Button { item.action() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(item.iconColor)
                            .frame(width: 20, height: 20)

                        Text(item.title)
                            .font(.system(size: 14, weight: .medium))

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        isFindFocused = false
        isAgentFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            showPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            mode = .none
        }
    }

    // MARK: - Task Selection

    private var selectedTaskBinding: Binding<TaskItem?> {
        Binding(
            get: {
                guard let id = selectedTaskID else { return nil }
                return tasks.first(where: { $0.id == id })
            },
            set: { newValue in
                selectedTaskID = newValue?.id
            }
        )
    }

    // MARK: - Agent Submit

    private func submitAgent() {
        let trimmed = agentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !agent.isProcessing, !isSynthesizing else { return }

        let query = trimmed
        agentInput = ""

        let isPlanQuery = detectPlanQuery(query)

        Task {
            let calEvents: [CalendarEvent]
            if let hasAccess = try? await eventKitService.requestCalendarAccess(), hasAccess {
                let start = Calendar.current.startOfDay(for: .now)
                let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
                calEvents = eventKitService.events(from: start, to: end)
            } else {
                calEvents = []
            }

            let ctx = AgentContext(
                modelContext: modelContext,
                areas: areas,
                projects: projects,
                tasks: tasks,
                calendarEvents: calEvents,
                eventKitService: eventKitService
            )

            if isPlanQuery {
                await submitSynthesis(query: query, ctx: ctx)
            } else {
                let response = await agent.process(query, apiKey: apiKey, context: ctx)
                withAnimation(.easeOut(duration: 0.25)) {
                    agentResponses.append(AgentResult(
                        query: query,
                        text: response.message,
                        taskCards: response.taskCards,
                        eventCards: response.eventCards,
                        subtasks: response.subtasks,
                        isPlanDay: response.isPlanDay,
                        pendingDeletion: response.pendingDeletion
                    ))
                }
            }
        }
    }

    private func submitSynthesis(query: String, ctx: AgentContext) async {
        isSynthesizing = true
        defer { isSynthesizing = false }

        let service = SynthesisService()
        let active = ctx.tasks.filter { $0.status == .active }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        let completedYesterday = ctx.tasks.filter {
            guard let d = $0.completedAt else { return false }
            return d >= yesterday && d < today
        }

        let hour = cal.component(.hour, from: .now)
        let period: String
        if hour >= 5 && hour < 12 { period = "morning" }
        else if hour >= 12 && hour < 17 { period = "afternoon" }
        else { period = "evening" }

        do {
            let result = try await service.generate(
                activeTasks: active,
                calendarEvents: [],
                areas: ctx.areas,
                completedYesterday: completedYesterday,
                apiKey: apiKey,
                period: period,
                weatherSummary: weatherService.promptSummary
            )

            let overdueTasks = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return d < today
            }
            let todayTasks = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return cal.isDateInToday(d)
            }

            var allRelevant: [TaskItem] = []
            allRelevant.append(contentsOf: overdueTasks)
            allRelevant.append(contentsOf: todayTasks.filter { t in
                !overdueTasks.contains(where: { $0.id == t.id })
            })

            let taskCards = allRelevant.prefix(12).map { task in
                AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
            }

            withAnimation(.easeOut(duration: 0.25)) {
                agentResponses.append(AgentResult(
                    query: query,
                    text: result.suggestedPlan,
                    taskCards: taskCards.isEmpty ? nil : Array(taskCards),
                    isPlanDay: true,
                    synthesis: SynthesisData(
                        greeting: result.greeting,
                        conflicts: result.conflicts,
                        suggestedPlan: result.suggestedPlan,
                        weatherSummary: weatherService.summary
                    )
                ))
            }
        } catch {
            let response = await agent.process(query, apiKey: apiKey, context: ctx)
            withAnimation(.easeOut(duration: 0.25)) {
                agentResponses.append(AgentResult(
                    query: query,
                    text: response.message,
                    taskCards: response.taskCards,
                    eventCards: response.eventCards,
                    subtasks: response.subtasks,
                    isPlanDay: response.isPlanDay
                ))
            }
        }
    }

    private func detectPlanQuery(_ query: String) -> Bool {
        let lower = query.lowercased()
        return lower.contains("plan my day") ||
               lower.contains("plan today") ||
               lower.contains("plan tomorrow") ||
               lower.contains("daily briefing") ||
               lower.contains("morning briefing") ||
               lower.contains("start my day") ||
               (lower.contains("plan") && lower.contains("day"))
    }

    // MARK: - Helpers

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    private func cleanAgentMessage(_ text: String, hasCards: Bool) -> String {
        var result = text
        if hasCards {
            let lines = result.components(separatedBy: "\n")
            let filtered = lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("·") && !t.hasPrefix("•") && !t.hasPrefix("- ")
            }
            result = filtered.joined(separator: "\n")
        }
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
