//
//  CommandPaletteOverlay.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - CommandPaletteOverlay

/// A unified glass overlay that combines Find (search) and Agent (AI chat) in one panel.
/// Inspired by the macOS Tether overlay with tabbed Find / Agent modes.
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
    @State private var weatherService = TetherWeatherService()
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
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showPanel)

            // Panel
            VStack(spacing: 0) {
                // Content area — animated expansion
                if mode == .find && findHasResults {
                    findResults
                        .transition(.opacity)
                } else if mode == .agent && hasAgentContent {
                    agentResults
                        .transition(.opacity)
                }

                if hasVisibleContent {
                    Divider().opacity(0.3).padding(.horizontal, 12)
                        .transition(.opacity)
                }

                // Input bar at bottom with integrated mode toggle
                inputBar
            }
            .contentShape(Rectangle())
            .onTapGesture { /* absorb taps on panel so they don't dismiss */ }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            .scaleEffect(showPanel ? 1 : 0.92)
            .opacity(showPanel ? 1 : 0)
            .offset(y: showPanel ? 0 : -12)
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: mode)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: hasAgentContent)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: findHasResults)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: agent.isProcessing)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSynthesizing)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
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

    // (Tab bar removed — mode toggle is integrated into the input bar)

    // MARK: - Input Bar with Integrated Mode Toggle

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Leading icon — tap to toggle mode
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    mode = mode == .find ? .agent : .find
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if mode == .find { isFindFocused = true }
                    else { isAgentFocused = true }
                }
            } label: {
                Image(systemName: mode == .find ? "magnifyingglass" : "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(mode == .find ? Color.secondary : Color.purple.opacity(0.7))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            // Text field — morphs between modes
            if mode == .find {
                TextField("Find", text: $findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .light))
                    .focused($isFindFocused)
            } else {
                TextField("Agent", text: $agentInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .light))
                    .focused($isAgentFocused)
                    .onSubmit { submitAgent() }
            }

            // Trailing accessory (clear / send / spinner)
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
                            .font(.system(size: 20))
                            .foregroundStyle(.primary.opacity(0.5))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .find { isFindFocused = true }
            else { isAgentFocused = true }
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
                .scrollIndicators(.hidden)
                .frame(maxHeight: 280)
                .clipped()
            }
        }
    }

    // MARK: - Agent Results

    private var agentResults: some View {
        Group {
            if !agentResponses.isEmpty || agent.isProcessing || isSynthesizing {
                agentResultsList
            }
        }
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
                        AgentResultAppearView(result: result, content: agentResultView(result))
                            .id(result.id)
                    }

                    if agent.isProcessing || isSynthesizing {
                        HStack {
                            ThinkingShimmer()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .id("thinking")
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 420)
            .clipped()
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

            if result.isPlanDay {
                // Calendar timeline view (matches macOS DailyPlanCard)
                dailyPlanView(result)
            } else {
                // Standard text + task cards
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

                if let cards = result.taskCards, !cards.isEmpty {
                    agentTaskList(cards)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Daily Plan View (Calendar Timeline)

    private func dailyPlanView(_ result: AgentResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Your Day + date + weather
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)

                Text("Your Day")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(dayDateLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    if let weather = result.synthesis?.weatherSummary {
                        Text(weather)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 16)
                .opacity(0.4)

            // Intro summary
            let parsed = parsePlan(from: result.text)

            if !parsed.intro.isEmpty {
                Text(markdownString(parsed.intro))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            // Schedule timeline blocks
            if !parsed.blocks.isEmpty {
                scheduleTimeline(parsed.blocks, eventCards: result.eventCards)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            } else if parsed.intro.isEmpty {
                // Fallback: render full text
                Text(markdownString(result.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }

            // Task cards below timeline
            if let cards = result.taskCards, !cards.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .opacity(0.3)

                agentTaskList(cards)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Schedule Timeline

    private func scheduleTimeline(_ blocks: [PlanTimeBlock], eventCards: [AgentEventCard]?) -> some View {
        VStack(spacing: 0) {
            ForEach(blocks) { block in
                let times = splitTimeRange(block.timeRange)
                HStack(alignment: .center, spacing: 0) {
                    // Time column
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(times.start)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.6))
                        if let end = times.end {
                            Text(end)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 65, alignment: .trailing)

                    // Accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor(for: block.blockType, eventCards: eventCards, description: block.description))
                        .frame(width: 3)
                        .padding(.leading, 8)
                        .padding(.trailing, 8)
                        .padding(.vertical, 2)

                    // Content
                    Text(markdownString(block.description))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                .padding(.trailing, 16)
            }
        }
    }

    // MARK: - Plan Parsing

    private struct PlanTimeBlock: Identifiable {
        let id = UUID()
        let timeRange: String
        let description: String
        let blockType: PlanBlockType
    }

    private enum PlanBlockType {
        case calendar, focus, errand, flex
    }

    private struct ParsedPlan {
        let intro: String
        let blocks: [PlanTimeBlock]
    }

    private func parsePlan(from text: String) -> ParsedPlan {
        let cleaned = text.replacingOccurrences(of: "\\n", with: "\n")
        var blocks = parseLineByLine(cleaned)
        if blocks.count <= 1 {
            blocks = parseInline(cleaned)
        }
        // Strip leftover markdown asterisks from time ranges and descriptions
        blocks = blocks.map { block in
            PlanTimeBlock(
                timeRange: block.timeRange.replacingOccurrences(of: "*", with: ""),
                description: block.description.replacingOccurrences(of: "*", with: ""),
                blockType: block.blockType
            )
        }
        let intro = extractIntro(from: cleaned)
        return ParsedPlan(intro: intro, blocks: blocks)
    }

    private func parseLineByLine(_ text: String) -> [PlanTimeBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [PlanTimeBlock] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, looksLikeTimeBlock(trimmed) else { continue }
            if let block = extractBlock(from: trimmed) {
                blocks.append(block)
            }
        }
        return blocks
    }

    private func parseInline(_ text: String) -> [PlanTimeBlock] {
        let timePattern = #"\*{0,2}(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]+\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\*{0,2}\s*[—–\-]\s*"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [] }
        var blocks: [PlanTimeBlock] = []
        for (i, match) in matches.enumerated() {
            let timeRange = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
            let descStart = match.range.location + match.range.length
            let descEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsText.length
            guard descStart < descEnd else { continue }
            let desc = nsText.substring(with: NSRange(location: descStart, length: descEnd - descStart))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ".")))
            guard !desc.isEmpty else { continue }
            blocks.append(PlanTimeBlock(timeRange: timeRange, description: desc, blockType: classifyBlock(desc)))
        }
        return blocks
    }

    private func extractBlock(from line: String) -> PlanTimeBlock? {
        let patterns = [
            #"^\*{1,2}(.+?)\*{1,2}\s*[—–\-]\s*(.+)$"#,
            #"^(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\s*[—–\-]\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 3,
               let r1 = Range(match.range(at: 1), in: line),
               let r2 = Range(match.range(at: 2), in: line) {
                let time = String(line[r1]).trimmingCharacters(in: .whitespaces)
                let desc = String(line[r2]).trimmingCharacters(in: .whitespaces)
                return PlanTimeBlock(timeRange: time, description: desc, blockType: classifyBlock(desc))
            }
        }
        for dash in ["—", "–", " - "] {
            if let range = line.range(of: dash) {
                let before = String(line[line.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
                let after = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if looksLikeTimeBlock(before) && !after.isEmpty {
                    return PlanTimeBlock(timeRange: before, description: after, blockType: classifyBlock(after))
                }
            }
        }
        return nil
    }

    private func extractIntro(from text: String) -> String {
        let stripped = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
        guard let match = stripped.range(of: #"\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?"#, options: .regularExpression) else {
            return ""
        }
        let intro = String(stripped[stripped.startIndex..<match.lowerBound])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "!.")))
        return intro.count > 10 ? intro : ""
    }

    private func looksLikeTimeBlock(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: "*", with: "")
        return stripped.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }

    private func classifyBlock(_ description: String) -> PlanBlockType {
        let lower = description.lowercased()
        if lower.contains("flex") || lower.contains("buffer") || lower.contains("wrap up") {
            return .flex
        }
        if lower.contains("lunch") || lower.contains("errand") || lower.contains("break") ||
           lower.contains("pick up") || lower.contains("gym") || lower.contains("run ") ||
           lower.contains("personal") {
            return .errand
        }
        return .focus
    }

    private func accentColor(for type: PlanBlockType, eventCards: [AgentEventCard]?, description: String) -> Color {
        if type == .calendar { return .blue }
        if let events = eventCards {
            let lower = description.lowercased()
            for event in events {
                if lower.contains(event.title.lowercased()) {
                    return .blue
                }
            }
        }
        switch type {
        case .focus:    return .orange
        case .errand:   return .green
        case .flex:     return .purple
        default:        return .orange
        }
    }

    private func splitTimeRange(_ range: String) -> (start: String, end: String?) {
        for sep in ["–", "—", "-"] {
            let parts = range.components(separatedBy: sep)
            if parts.count == 2 {
                let start = parts[0].trimmingCharacters(in: .whitespaces)
                let end = parts[1].trimmingCharacters(in: .whitespaces)
                return (start, end.isEmpty ? nil : end)
            }
        }
        return (range.trimmingCharacters(in: .whitespaces), nil)
    }

    private var dayDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: Date())
    }

    private func agentTaskList(_ cards: [AgentTaskCard]) -> some View {
        VStack(spacing: 0) {
            ForEach(cards.prefix(8)) { task in
                Button {
                    selectedTaskID = task.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(task.isCompleted ? .green : Color.primary.opacity(0.2))

                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                            .lineLimit(1)

                        Spacer()

                        if let date = task.whenDate ?? task.deadline {
                            Text(shortDate(date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(date < Calendar.current.startOfDay(for: .now) ? Color.red : Color.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
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

    private var hasAgentContent: Bool {
        !agentResponses.isEmpty || agent.isProcessing || isSynthesizing
    }

    private var hasVisibleContent: Bool {
        if mode == .find { return findHasResults }
        return hasAgentContent || agent.isProcessing || isSynthesizing
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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

// MARK: - Appear Animation Wrapper

/// Wraps an agent result view so it fades + slides in on appear.
private struct AgentResultAppearView<Content: View>: View {
    let result: Any
    let content: Content
    @State private var visible = false

    var body: some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 6)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    visible = true
                }
            }
    }
}
