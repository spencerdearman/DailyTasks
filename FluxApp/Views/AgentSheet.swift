//
//  AgentSheet.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - AgentSheet

/// A sheet-based AI agent interface for natural language task management on iOS.
struct AgentSheet: View {

    // MARK: Queries & Environment

    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var apiKey = ""

    // MARK: State

    @State private var agent = TaskAgent()
    @State private var weatherService = FluxWeatherService()
    @State private var input = ""
    @State private var responses: [AgentResult] = []
    @State private var showOverdueTasks = false
    @State private var isSynthesizing = false
    @FocusState private var isFocused: Bool

    // MARK: Result Model

    private struct AgentResult: Identifiable {
        let id = UUID()
        let query: String
        let text: String
        let taskCards: [AgentTaskCard]?
        let eventCards: [AgentEventCard]?
        let subtasks: [String]?
        let isPlanDay: Bool
        var synthesis: SynthesisData?
    }

    /// Extra data for synthesis-style plan day responses.
    private struct SynthesisData {
        let greeting: String
        let conflicts: [String]
        let suggestedPlan: String
        let overdueTasks: [AgentTaskCard]
        let weatherSummary: String?
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if responses.isEmpty && !agent.isProcessing && !isSynthesizing {
                    emptyState
                } else {
                    resultsList
                }

                Divider()

                inputBar
            }
            .navigationTitle("Flux Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .task {
            await weatherService.fetchWeather()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("Ask Flux anything")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                suggestionChip("Plan my day")
                suggestionChip("What's on my plate today?")
                suggestionChip("Add a task to buy groceries")
                suggestionChip("Show my inbox")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            input = text
            submit()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(responses.enumerated()), id: \.element.id) { index, result in
                        if index > 0 {
                            Divider()
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                        }
                        resultView(result)
                            .id(result.id)
                    }

                    if agent.isProcessing || isSynthesizing {
                        thinkingView
                            .id("thinking")
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: responses.count) {
                if let last = responses.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Result View

    private func resultView(_ result: AgentResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Query chip
            HStack(spacing: 5) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.quaternary)
                Text(result.query)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if result.isPlanDay, let synthesis = result.synthesis {
                synthesisPlanContent(result, synthesis: synthesis)
            } else if result.isPlanDay {
                planDayContent(result)
            } else {
                standardResultContent(result)
            }
        }
    }

    private func standardResultContent(_ result: AgentResult) -> some View {
        let hasCards = result.taskCards != nil || result.eventCards != nil
        let displayText = cleanMessage(result.text, hasCards: hasCards)

        return VStack(alignment: .leading, spacing: 0) {
            if !displayText.isEmpty {
                Text(markdownString(displayText))
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.bottom, hasCards ? 8 : 4)
            }

            if let events = result.eventCards, !events.isEmpty {
                eventTimeline(events)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            if let cards = result.taskCards, !cards.isEmpty {
                taskChips(cards)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            if let subtasks = result.subtasks, !subtasks.isEmpty {
                subtaskList(subtasks)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Synthesis Plan Day Content

    private func synthesisPlanContent(_ result: AgentResult, synthesis: SynthesisData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(periodGreeting)
                        .font(.system(size: 20, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 18)

            // Weather
            if let weather = synthesis.weatherSummary {
                HStack(spacing: 6) {
                    Image(systemName: weatherIcon(for: weather))
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                    Text(weather)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, 18)
            }

            // Greeting
            if !synthesis.greeting.isEmpty {
                Text(markdownString(synthesis.greeting))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
            }

            // Heads Up (conflicts)
            if !synthesis.conflicts.isEmpty {
                synthesisSection("Heads Up", icon: "exclamationmark.triangle.fill", iconColor: .orange) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(synthesis.conflicts.enumerated()), id: \.offset) { _, conflict in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.orange.opacity(0.6))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                Text(markdownString(conflict))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary.opacity(0.75))
                                    .lineSpacing(2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            // Your Day timeline
            if !synthesis.suggestedPlan.isEmpty {
                suggestedPlanTimeline(synthesis.suggestedPlan)
                    .padding(.horizontal, 12)
            }

            // Overdue tasks
            if !synthesis.overdueTasks.isEmpty {
                overdueSection(synthesis.overdueTasks)
                    .padding(.horizontal, 12)
            }

            // Task cards
            if let cards = result.taskCards, !cards.isEmpty {
                taskChips(cards)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Simple Plan Day (fallback)

    private func planDayContent(_ result: AgentResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("Your Day")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(dayLabel(Date()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            if !result.text.isEmpty {
                Text(markdownString(result.text))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }

            if let events = result.eventCards, !events.isEmpty {
                eventTimeline(events)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            if let cards = result.taskCards, !cards.isEmpty {
                taskChips(cards)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Suggested Plan Timeline

    private func suggestedPlanTimeline(_ text: String) -> some View {
        let blocks = parseTimeBlocks(text)

        return synthesisSection("Your Day", icon: "calendar.badge.clock", iconColor: .blue) {
            if blocks.isEmpty {
                Text(markdownString(text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(3)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            // Accent dot
                            Circle()
                                .fill(accentColor(for: block.blockType))
                                .frame(width: 6, height: 6)
                                .padding(.trailing, 8)

                            // Combined time + description
                            Text(markdownString("*\(block.timeRange)*: \(block.description)"))
                                .font(.system(size: 13))
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 7)

                        if index < blocks.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                                .opacity(0.2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overdue Section

    private func overdueSection(_ overdueTasks: [AgentTaskCard]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showOverdueTasks.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))

                    Text("\(overdueTasks.count) overdue tasks need attention")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.7))

                    Spacer()

                    Image(systemName: showOverdueTasks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showOverdueTasks {
                VStack(spacing: 0) {
                    ForEach(overdueTasks.prefix(8)) { task in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.25))

                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            if let date = task.whenDate ?? task.deadline {
                                Text(shortDate(date))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.red.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Synthesis Section Helper

    private func synthesisSection<Content: View>(
        _ title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Event Timeline

    private func eventTimeline(_ events: [AgentEventCard]) -> some View {
        let grouped = groupEventsByDay(events)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                Text(dayLabel(group.date))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 3)

                ForEach(group.events) { event in
                    HStack(spacing: 8) {
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 52, alignment: .trailing)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 2.5)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if let loc = event.location, !loc.isEmpty {
                                Text(loc)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text(duration(from: event.startDate, to: event.endDate))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Task Chips

    private func taskChips(_ cards: [AgentTaskCard]) -> some View {
        VStack(spacing: 2) {
            ForEach(cards) { task in
                HStack(spacing: 8) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(task.isCompleted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary.opacity(0.35)))

                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(task.isCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary.opacity(0.85)))
                        .strikethrough(task.isCompleted, color: .secondary.opacity(0.4))
                        .lineLimit(1)

                    Spacer()

                    if let project = task.project {
                        Text(project)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    if let date = task.whenDate ?? task.deadline {
                        Text(shortDate(date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isOverdue(date) ? .red.opacity(0.8) : .secondary)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Subtask List

    private func subtaskList(_ subtasks: [String]) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(subtasks.enumerated()), id: \.offset) { _, subtask in
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.25))
                    Text(subtask)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Thinking

    private var thinkingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Thinking...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, isActive: agent.isProcessing || isSynthesizing)

            TextField("Ask Flux anything...", text: $input)
                .font(.body)
                .focused($isFocused)
                .onSubmit { submit() }
                .textFieldStyle(.plain)

            if agent.isProcessing || isSynthesizing {
                ProgressView()
                    .controlSize(.small)
            } else if !input.isEmpty {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !agent.isProcessing, !isSynthesizing else { return }

        let query = trimmed
        input = ""

        // Detect if this is a "plan day" type query to trigger synthesis
        let isPlanQuery = detectPlanQuery(query)

        Task {
            let ctx = AgentContext(
                modelContext: modelContext,
                areas: areas,
                projects: projects,
                tasks: tasks,
                calendarEvents: []
            )

            if isPlanQuery {
                await submitSynthesis(query: query, ctx: ctx)
            } else {
                let response = await agent.process(query, apiKey: apiKey, context: ctx)

                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
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

        let overdueTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return d < today
        }

        let todayTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return cal.isDateInToday(d)
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

            // Build task cards for today + overdue
            var allRelevant: [TaskItem] = []
            allRelevant.append(contentsOf: overdueTasks)
            allRelevant.append(contentsOf: todayTasks.filter { t in
                !overdueTasks.contains(where: { $0.id == t.id })
            })
            let inboxTasks = active.filter(\.isInInbox)
            allRelevant.append(contentsOf: inboxTasks.filter { t in
                !allRelevant.contains(where: { $0.id == t.id })
            })

            let taskCards = allRelevant.prefix(15).map { task in
                AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
            }

            let overdueCards = overdueTasks.prefix(10).map { task in
                AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: false)
            }

            withAnimation(.easeOut(duration: 0.25)) {
                responses.append(AgentResult(
                    query: query,
                    text: result.suggestedPlan,
                    taskCards: taskCards.isEmpty ? nil : Array(taskCards),
                    eventCards: nil,
                    subtasks: nil,
                    isPlanDay: true,
                    synthesis: SynthesisData(
                        greeting: result.greeting,
                        conflicts: result.conflicts,
                        suggestedPlan: result.suggestedPlan,
                        overdueTasks: Array(overdueCards),
                        weatherSummary: weatherService.summary
                    )
                ))
            }
        } catch {
            print("[Synthesis] Error: \(error)")
            // Fallback to regular agent
            let response = await agent.process(query, apiKey: apiKey, context: ctx)
            withAnimation(.easeOut(duration: 0.25)) {
                responses.append(AgentResult(
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

    // MARK: - Period-Aware Text

    private var periodGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 12 { return "Good Morning" }
        if hour >= 12 && hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Time Block Parsing

    private struct TimeBlock: Identifiable {
        let id = UUID()
        let timeRange: String
        let description: String
        let blockType: BlockType

        enum BlockType {
            case calendar, focus, errand, flex
        }
    }

    private func parseTimeBlocks(_ text: String) -> [TimeBlock] {
        var blocks: [TimeBlock] = []
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, looksLikeTimeBlock(trimmed) else { continue }
            if let block = extractBlock(from: trimmed) {
                blocks.append(block)
            }
        }
        if blocks.count > 1 { return blocks }

        // Inline fallback
        let timePattern = #"\*{0,2}(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]+\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\*{0,2}\s*[—–:]\s*"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []) else { return blocks }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return blocks }

        blocks = []
        for (i, match) in matches.enumerated() {
            let timeRange = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
            let descStart = match.range.location + match.range.length
            let descEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsText.length
            guard descStart < descEnd else { continue }
            let desc = nsText.substring(with: NSRange(location: descStart, length: descEnd - descStart))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ".")))
            guard !desc.isEmpty else { continue }
            blocks.append(TimeBlock(timeRange: timeRange, description: desc, blockType: classifyBlock(desc)))
        }
        return blocks
    }

    private func extractBlock(from line: String) -> TimeBlock? {
        let patterns = [
            #"^\*{1,2}(.+?)\*{1,2}\s*[—–\-:]\s*(.+)$"#,
            #"^(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\s*[—–\-:]\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 3,
               let r1 = Range(match.range(at: 1), in: line),
               let r2 = Range(match.range(at: 2), in: line) {
                let time = String(line[r1]).trimmingCharacters(in: .whitespaces)
                let desc = String(line[r2]).trimmingCharacters(in: .whitespaces)
                return TimeBlock(timeRange: time, description: desc, blockType: classifyBlock(desc))
            }
        }
        for dash in ["—", "–", " - ", ": "] {
            if let range = line.range(of: dash) {
                let before = String(line[line.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
                let after = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if looksLikeTimeBlock(before) && !after.isEmpty {
                    return TimeBlock(timeRange: before, description: after, blockType: classifyBlock(after))
                }
            }
        }
        return nil
    }

    private func looksLikeTimeBlock(_ line: String) -> Bool {
        line.replacingOccurrences(of: "*", with: "")
            .range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }

    private func classifyBlock(_ description: String) -> TimeBlock.BlockType {
        let lower = description.lowercased()
        if lower.contains("flex") || lower.contains("buffer") || lower.contains("wrap up") { return .flex }
        if lower.contains("lunch") || lower.contains("errand") || lower.contains("break") ||
           lower.contains("pick up") || lower.contains("gym") || lower.contains("run ") ||
           lower.contains("personal") { return .errand }
        return .focus
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

    private func accentColor(for type: TimeBlock.BlockType) -> Color {
        switch type {
        case .calendar: return .blue
        case .focus:    return .orange
        case .errand:   return .green
        case .flex:     return .purple
        }
    }

    // MARK: - Helpers

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    private func cleanMessage(_ text: String, hasCards: Bool) -> String {
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

    private func weatherIcon(for summary: String) -> String {
        let lower = summary.lowercased()
        if lower.contains("rain") || lower.contains("shower") { return "cloud.rain.fill" }
        if lower.contains("cloud") || lower.contains("overcast") { return "cloud.fill" }
        if lower.contains("snow") { return "cloud.snow.fill" }
        if lower.contains("storm") || lower.contains("thunder") { return "cloud.bolt.fill" }
        if lower.contains("wind") { return "wind" }
        if lower.contains("fog") { return "cloud.fog.fill" }
        return "sun.max.fill"
    }

    private struct DayGroup {
        let date: Date
        let events: [AgentEventCard]
    }

    private func groupEventsByDay(_ events: [AgentEventCard]) -> [DayGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { cal.startOfDay(for: $0.startDate) }
        return grouped
            .sorted { $0.key < $1.key }
            .map { DayGroup(date: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func duration(from start: Date, to end: Date) -> String {
        let mins = Int(end.timeIntervalSince(start) / 60)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tmrw" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: .now)
    }
}
