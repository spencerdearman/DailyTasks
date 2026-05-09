//
//  AgentOverlay.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct AgentOverlay: View {
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var calendarStore: CalendarStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var weatherService: TetherWeatherService
    @AppStorage("geminiAPIKey") private var apiKey = ""

    let onDismiss: () -> Void
    var onSelectTask: ((UUID) -> Void)?

    @Query(sort: \AgentConversation.updatedAt, order: .reverse) private var recentConversations: [AgentConversation]

    @State private var agent = TaskAgent()
    @State private var input = ""
    @State private var responses: [AgentResult] = []
    @State private var showPanel = false
    @State private var currentConversation: AgentConversation?
    @State private var hoveredPipIndex: Int?
    @State private var selectedPipIndex: Int?
    @State private var showPips = false
    @State private var isHoveringHistoryPip = false
    @State private var isHoveringHistoryList = false
    @State private var historyDismissTask: Task<Void, Never>?
    @State private var showHistoryListStable = false
    @State private var resultContentHeight: CGFloat = 0
    @FocusState private var isFocused: Bool

    // MARK: - Result Model

    private struct AgentResult: Identifiable {
        let id = UUID()
        let query: String
        let text: String
        let taskCards: [TaskCard]?
        let eventCards: [EventCard]?
        let subtasks: [String]?
        let isPlanDay: Bool
        let proposal: ScheduleProposal?
        let pendingDeletion: EventDeletion?

        init(query: String, text: String, taskCards: [TaskCard]? = nil, eventCards: [EventCard]? = nil, subtasks: [String]? = nil, isPlanDay: Bool = false, proposal: ScheduleProposal? = nil, pendingDeletion: EventDeletion? = nil) {
            self.query = query
            self.text = text
            self.taskCards = taskCards
            self.eventCards = eventCards
            self.subtasks = subtasks
            self.isPlanDay = isPlanDay
            self.proposal = proposal
            self.pendingDeletion = pendingDeletion
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(showPanel ? 0.1 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .animation(.easeOut(duration: 0.2), value: showPanel)

            GeometryReader { geo in
                VStack(spacing: 0) {
                    searchBar

                    ghostPreview

                    ZStack {
                        if !responses.isEmpty || agent.isProcessing {
                            resultArea
                                .opacity(showHistoryList ? 0 : 1)
                        }

                        if showHistoryList {
                            historyListView
                                .onHover { hovering in
                                    isHoveringHistoryList = hovering
                                    updateHistoryVisibility()
                                }
                        }
                    }
                    .animation(nil, value: showHistoryList)
                }
                .frame(width: 580)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .shadow(color: .black.opacity(0.35), radius: 40, y: 12)
                .scaleEffect(showPanel ? 1 : 0.97)
                .opacity(showPanel ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, geo.size.height * 0.28)
            }
        }
        .onAppear {
            pruneOldConversations()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showPanel = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showPips = true
                }
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private var hasContent: Bool {
        !responses.isEmpty || agent.isProcessing
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse, isActive: agent.isProcessing)

            TextField("Agent", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .light))
                .focused($isFocused)
                .onSubmit { submit() }

            if !recentConversations.isEmpty {
                scrubberPips
                    .opacity(showPips ? (hasContent ? 0.3 : 1) : 0)
                    .animation(.easeOut(duration: 0.2), value: hasContent)
                    .animation(.easeOut(duration: 0.3), value: showPips)
            }

            if agent.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
                    .transition(.blurReplace)
            } else if !input.isEmpty {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 22)
                .transition(.blurReplace)
            }
        }
        .frame(minHeight: 22)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: input.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: agent.isProcessing)
    }

    // MARK: - Result Area

    private var resultArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(responses.enumerated()), id: \.element.id) { index, result in
                        if index > 0 {
                            Divider()
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                        }
                        RevealView {
                            resultView(result)
                        }
                        .id(result.id)
                    }

                    if agent.isProcessing {
                        thinkingView
                            .id("thinking")
                    }

                    if !responses.isEmpty && !agent.isProcessing {
                        Text("AI can make mistakes.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                    }
                }
                .padding(.bottom, 10)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ResultContentHeightKey.self, value: geo.size.height)
                })
            }
            .onPreferenceChange(ResultContentHeightKey.self) { height in
                withAnimation(.easeOut(duration: 0.35)) {
                    resultContentHeight = height
                }
            }
            .scrollIndicatorsFlash(onAppear: false)
            .scrollContentBackground(.hidden)
            .frame(height: min(resultContentHeight, 400))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 6)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 4)
                }
            )
            .onChange(of: responses.count) {
                // Delay so RevealView animation has started and content has height
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let last = responses.last {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(last.id, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: agent.isProcessing) {
                if agent.isProcessing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private struct ResultContentHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    // MARK: - Result View

    private func resultView(_ result: AgentResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Query — shown as a subtle chip
            HStack(spacing: 5) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.quaternary)
                Text(result.query)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if result.isPlanDay {
                DailyPlanCard(
                    message: result.text,
                    taskCards: result.taskCards,
                    eventCards: result.eventCards,
                    weatherSummary: weatherService.summary,
                    weatherService: weatherService,
                    onSelectTask: { taskID in onSelectTask?(taskID) }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            } else if let proposal = result.proposal {
                ScheduleProposalCard(proposal: proposal) { option in
                    acceptProposal(proposal: proposal, option: option)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            } else if let deletion = result.pendingDeletion {
                deletionResultContent(result, deletion: deletion)
            } else {
                standardResultContent(result)
            }
        }
    }

    private func standardResultContent(_ result: AgentResult) -> some View {
        let hasCards = result.taskCards != nil || result.eventCards != nil
        let displayText = cleanMessage(result.text, hasCards: hasCards)

        return VStack(alignment: .leading, spacing: 0) {
            // Response text
            if !displayText.isEmpty {
                Text(markdownString(displayText))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(2.5)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.bottom, hasCards ? 8 : 4)
            }

            // Event timeline
            if let events = result.eventCards, !events.isEmpty {
                eventTimeline(events)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Task chips
            if let cardItems = result.taskCards, !cardItems.isEmpty {
                taskChips(cardItems)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // Subtasks
            if let subtasks = result.subtasks, !subtasks.isEmpty {
                subtaskList(subtasks)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Event Timeline

    private func eventTimeline(_ events: [EventCard]) -> some View {
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
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Task Chips (tappable)

    private func taskChips(_ cardItems: [TaskCard]) -> some View {
        VStack(spacing: 2) {
            ForEach(cardItems) { task in
                Button {
                    onSelectTask?(task.id)
                } label: {
                    HStack(spacing: 8) {
                        Group {
                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                            }
                        }
                        .font(.system(size: 14))

                        Text(task.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary.opacity(0.85))
                            .strikethrough(task.isCompleted, color: Color.secondary.opacity(0.4))
                            .lineLimit(1)

                        Spacer()

                        if let project = task.project {
                            Text(project)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        if let date = task.whenDate ?? task.deadline {
                            Text(shortDate(date))
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(isOverdue(date) ? Color.red.opacity(0.8) : Color.gray)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Subtask List

    private func subtaskList(_ subtasks: [String]) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(subtasks.enumerated()), id: \.offset) { _, subtask in
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary.opacity(0.25))

                    Text(subtask)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Thinking

    private var thinkingView: some View {
        ThinkingShimmer()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
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
        // Remove bullet lines when we have cards
        if hasCards {
            let lines = result.components(separatedBy: "\n")
            let filtered = lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("·") && !t.hasPrefix("•") && !t.hasPrefix("- ")
            }
            result = filtered.joined(separator: "\n")
        }
        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct DayGroup {
        let date: Date
        let events: [EventCard]
    }

    private func groupEventsByDay(_ events: [EventCard]) -> [DayGroup] {
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
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: .now)
    }

    // MARK: - Temporal Scrubber

    /// The 3 quick-access conversations (middle pips).
    private var quickAccessConversations: [AgentConversation] {
        Array(recentConversations.prefix(3))
    }

    /// Whether there are more conversations beyond the 3 quick-access ones.
    private var hasMoreHistory: Bool {
        recentConversations.count > 3
    }

    private var showHistoryList: Bool {
        showHistoryListStable
    }

    private func updateHistoryVisibility() {
        let shouldShow = isHoveringHistoryPip || isHoveringHistoryList
        if shouldShow {
            historyDismissTask?.cancel()
            historyDismissTask = nil
            if !showHistoryListStable {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showHistoryListStable = true
                }
            }
        } else {
            historyDismissTask?.cancel()
            historyDismissTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if !isHoveringHistoryPip && !isHoveringHistoryList {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showHistoryListStable = false
                        }
                    }
                }
            }
        }
    }

    private var scrubberPips: some View {
        HStack(spacing: 0) {
            // Pip 1: "New chat" — leftmost, always highlighted when active
            Circle()
                .fill(selectedPipIndex == nil ? Color.primary.opacity(0.5) : Color.primary.opacity(0.15))
                .frame(width: selectedPipIndex == nil ? 6.5 : 5.5, height: selectedPipIndex == nil ? 6.5 : 5.5)
                .frame(width: 17, height: 17)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        hoveredPipIndex = hovering ? -1 : nil
                    }
                }
                .onTapGesture {
                    startNewConversation()
                }

            // Pips 2-4: Quick access (up to 3 recent conversations)
            ForEach(Array(quickAccessConversations.enumerated()), id: \.element.id) { index, conversation in
                Circle()
                    .fill(selectedPipIndex == index ? Color.primary.opacity(0.5) : Color.primary.opacity(hoveredPipIndex == index ? 0.3 : 0.15))
                    .frame(width: selectedPipIndex == index ? 6.5 : 5.5, height: selectedPipIndex == index ? 6.5 : 5.5)
                    .frame(width: 17, height: 17)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoveredPipIndex = hovering ? index : nil
                        }
                    }
                    .onTapGesture {
                        loadConversation(at: index)
                    }
            }

            // Pip 5: "History" — rightmost, hover to peek at full history
            if hasMoreHistory || !recentConversations.isEmpty {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(showHistoryList ? Color.accentColor.opacity(0.8) : Color.primary.opacity(isHoveringHistoryPip ? 0.4 : 0.2))
                    .frame(width: 17, height: 17)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringHistoryPip = hovering
                        if hovering { hoveredPipIndex = -2 }
                        updateHistoryVisibility()
                    }
            }
        }
        .animation(.easeOut(duration: 0.15), value: selectedPipIndex)
        .animation(.easeOut(duration: 0.15), value: hoveredPipIndex)
        .animation(.easeOut(duration: 0.15), value: isHoveringHistoryPip)
    }

    @ViewBuilder
    private var ghostPreview: some View {
        if let idx = hoveredPipIndex, idx >= 0, idx < quickAccessConversations.count, !showHistoryList {
            let conversation = quickAccessConversations[idx]
            HStack {
                Text(conversation.firstQuery)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(relativeTime(conversation.updatedAt))
                    .foregroundStyle(.quaternary)
            }
            .font(.system(size: 15, weight: .light))
            .padding(.horizontal, 18)
            .padding(.top, 5)
            .padding(.bottom, 10)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: hoveredPipIndex)
        }
    }

    // MARK: - History List

    private var historyListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(recentConversations.enumerated()), id: \.element.id) { index, conversation in
                    Button {
                        isHoveringHistoryPip = false
                        isHoveringHistoryList = false
                        historyDismissTask?.cancel()
                        showHistoryListStable = false
                        loadConversation(fromAll: conversation)
                    } label: {
                        HStack {
                            Text(conversation.firstQuery)
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Text(relativeTime(conversation.updatedAt))
                                .font(.system(size: 13, weight: .light))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < recentConversations.count - 1 {
                        Divider()
                            .padding(.horizontal, 20)
                            .opacity(0.3)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 400)
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 6)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 4)
            }
        )
    }

    private func loadConversation(fromAll conversation: AgentConversation) {
        let messages = conversation.decodeMessages()

        var results: [AgentResult] = []
        var i = 0
        while i < messages.count {
            let msg = messages[i]
            if msg.role == .user {
                let assistantMsg = (i + 1 < messages.count && messages[i + 1].role == .assistant) ? messages[i + 1] : nil
                let text = assistantMsg?.text ?? ""
                let taskCards = assistantMsg?.taskCardsJSON.flatMap { decodeTaskCards($0) }
                let eventCards = assistantMsg?.eventCardsJSON.flatMap { decodeEventCards($0) }
                let subtasks = assistantMsg?.subtasksJSON.flatMap { decodeSubtasks($0) }
                let isPlanDay = assistantMsg?.isPlanDay ?? false
                results.append(AgentResult(
                    query: msg.text,
                    text: text,
                    taskCards: taskCards,
                    eventCards: eventCards,
                    subtasks: subtasks,
                    isPlanDay: isPlanDay
                ))
                i += assistantMsg != nil ? 2 : 1
            } else {
                i += 1
            }
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            responses = results
            currentConversation = conversation
            // Find which quick-access index, if any
            if let qIdx = quickAccessConversations.firstIndex(where: { $0.id == conversation.id }) {
                selectedPipIndex = qIdx
            } else {
                selectedPipIndex = nil
            }
        }
        input = ""
    }

    private func loadConversation(at index: Int) {
        guard index < quickAccessConversations.count else { return }
        loadConversation(fromAll: quickAccessConversations[index])
    }

    private func startNewConversation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            responses = []
            selectedPipIndex = nil
            currentConversation = nil
        }
        input = ""
    }

    private func saveUserMessage(_ query: String) {
        if currentConversation == nil {
            let conversation = AgentConversation(firstQuery: query)
            modelContext.insert(conversation)
            currentConversation = conversation
        }
        currentConversation?.appendMessage(ConversationMessage(
            role: .user, text: query,
            taskCardsJSON: nil, eventCardsJSON: nil, subtasksJSON: nil,
            isPlanDay: false, timestamp: Date()
        ))
        try? modelContext.save()
    }

    private func saveAssistantMessage(_ result: AgentResult) {
        let taskCardsJSON = result.taskCards.flatMap { encodeTaskCards($0) }
        let eventCardsJSON = result.eventCards.flatMap { encodeEventCards($0) }
        let subtasksJSON = result.subtasks.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        currentConversation?.appendMessage(ConversationMessage(
            role: .assistant, text: result.text,
            taskCardsJSON: taskCardsJSON, eventCardsJSON: eventCardsJSON,
            subtasksJSON: subtasksJSON,
            isPlanDay: result.isPlanDay, timestamp: Date()
        ))
        try? modelContext.save()
    }

    private func pruneOldConversations() {
        guard let cutoff = Calendar.current.date(byAdding: .hour, value: -48, to: .now) else { return }
        let old = recentConversations.filter { $0.updatedAt < cutoff }
        old.forEach { modelContext.delete($0) }
        if !old.isEmpty { try? modelContext.save() }
    }

    // MARK: Conversation Serialization

    private func encodeTaskCards(_ cards: [TaskCard]) -> String? {
        struct CodableCard: Codable {
            let id: String; let title: String; let project: String?; let area: String?
            let whenDate: Date?; let deadline: Date?; let isCompleted: Bool
        }
        let codable = cards.map { CodableCard(id: $0.id.uuidString, title: $0.title, project: $0.project, area: $0.area, whenDate: $0.whenDate, deadline: $0.deadline, isCompleted: $0.isCompleted) }
        return (try? String(data: JSONEncoder().encode(codable), encoding: .utf8))
    }

    private func decodeTaskCards(_ json: String) -> [TaskCard]? {
        struct CodableCard: Codable {
            let id: String; let title: String; let project: String?; let area: String?
            let whenDate: Date?; let deadline: Date?; let isCompleted: Bool
        }
        guard let data = json.data(using: .utf8),
              let codable = try? JSONDecoder().decode([CodableCard].self, from: data) else { return nil }
        let cards = codable.map { TaskCard(id: UUID(uuidString: $0.id) ?? UUID(), title: $0.title, project: $0.project, area: $0.area, whenDate: $0.whenDate, deadline: $0.deadline, isCompleted: $0.isCompleted) }
        return cards.isEmpty ? nil : cards
    }

    private func encodeEventCards(_ cards: [EventCard]) -> String? {
        struct CodableCard: Codable {
            let id: String; let title: String; let startDate: Date; let endDate: Date
            let location: String?; let isAllDay: Bool
        }
        let codable = cards.map { CodableCard(id: $0.id, title: $0.title, startDate: $0.startDate, endDate: $0.endDate, location: $0.location, isAllDay: $0.isAllDay) }
        return (try? String(data: JSONEncoder().encode(codable), encoding: .utf8))
    }

    private func decodeEventCards(_ json: String) -> [EventCard]? {
        struct CodableCard: Codable {
            let id: String; let title: String; let startDate: Date; let endDate: Date
            let location: String?; let isAllDay: Bool
        }
        guard let data = json.data(using: .utf8),
              let codable = try? JSONDecoder().decode([CodableCard].self, from: data) else { return nil }
        let cards = codable.map { EventCard(id: $0.id, title: $0.title, startDate: $0.startDate, endDate: $0.endDate, location: $0.location, isAllDay: $0.isAllDay) }
        return cards.isEmpty ? nil : cards
    }

    private func decodeSubtasks(_ json: String) -> [String]? {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return arr.isEmpty ? nil : arr
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "Yesterday"
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !agent.isProcessing else { return }

        let query = trimmed
        input = ""

        // If starting fresh (no selected pip), clear selection
        if selectedPipIndex != nil && currentConversation == nil {
            selectedPipIndex = nil
        }

        saveUserMessage(query)

        // Ensure calendar events are fresh before building the agent context
        calendarStore.refresh()

        Task {
            let ctx = AgentContext(
                modelContext: modelContext,
                calendarStore: calendarStore,
                locationService: locationService,
                weatherSummary: weatherService.promptSummary,
                areas: areas,
                projects: projects,
                tasks: tasks,
                calendarEvents: calendarStore.allEvents
            )
            let response = await agent.process(
                query,
                apiKey: apiKey,
                context: ctx
            )

            let result = AgentResult(
                query: query,
                text: response.message,
                taskCards: response.taskCards,
                eventCards: response.eventCards,
                subtasks: response.subtasks,
                isPlanDay: response.isPlanDay,
                proposal: response.proposal,
                pendingDeletion: response.pendingDeletion
            )

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                responses.append(result)
            }

            saveAssistantMessage(result)
        }
    }

    private func acceptProposal(proposal: ScheduleProposal, option: ScheduleOption) {
        Task {
            do {
                let event = try await calendarStore.createEvent(
                    title: proposal.eventTitle,
                    startDate: option.startDate,
                    endDate: option.endDate,
                    location: option.location
                )
                let card = EventCard(
                    id: event.id, title: event.title,
                    startDate: event.startDate, endDate: event.endDate,
                    location: event.location, isAllDay: false
                )
                let timeFmt = DateFormatter()
                timeFmt.dateFormat = "h:mm a"

                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
                        query: "Schedule: \(proposal.eventTitle)",
                        text: "Scheduled **\(proposal.eventTitle)** for \(timeFmt.string(from: option.startDate)) – \(timeFmt.string(from: option.endDate)).",
                        taskCards: nil,
                        eventCards: [card],
                        subtasks: nil,
                        isPlanDay: false,
                        proposal: nil
                    ))
                }
            } catch {
                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
                        query: "Schedule: \(proposal.eventTitle)",
                        text: "Failed to create event: \(error.localizedDescription)",
                        taskCards: nil, eventCards: nil, subtasks: nil,
                        isPlanDay: false, proposal: nil
                    ))
                }
            }
        }
    }

    // MARK: - Delete Confirmation

    private func deletionResultContent(_ result: AgentResult, deletion: EventDeletion) -> some View {
        let hasCards = result.eventCards != nil
        let displayText = cleanMessage(result.text, hasCards: hasCards)

        return VStack(alignment: .leading, spacing: 0) {
            if !displayText.isEmpty {
                Text(markdownString(displayText))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(2.5)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }

            // Event card with integrated buttons
            if let events = result.eventCards, let event = events.first {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayLabel(event.startDate))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 3)

                    HStack(spacing: 8) {
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 52, alignment: .trailing)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.red.opacity(0.5))
                            .frame(width: 2.5)

                        Text(event.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text(duration(from: event.startDate, to: event.endDate))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)

                    Divider()
                        .opacity(0.3)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)

                    // Inline action buttons
                    deleteConfirmation(for: deletion)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
    }

    private func deleteConfirmation(for deletion: EventDeletion) -> some View {
        HStack(spacing: 8) {
            Button {
                confirmDeletion(deletion)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                    Text("Remove")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.red.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
                        query: "Keep: \(deletion.eventTitle)",
                        text: "Kept **\(deletion.eventTitle)** on your calendar."
                    ))
                }
            } label: {
                Text("Keep")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func confirmDeletion(_ deletion: EventDeletion) {
        Task {
            do {
                try await calendarStore.deleteEvent(withID: deletion.eventID)
                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
                        query: "Deleted: \(deletion.eventTitle)",
                        text: "**\(deletion.eventTitle)** has been removed from your calendar."
                    ))
                }
            } catch {
                withAnimation(.easeOut(duration: 0.25)) {
                    responses.append(AgentResult(
                        query: "Delete: \(deletion.eventTitle)",
                        text: "Failed to delete event: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Reveal Animation

/// Wraps content in a top-to-bottom gradient mask reveal.
private struct RevealView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var reveal: CGFloat = 0

    var body: some View {
        content
            .opacity(reveal)
            .mask(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: min(reveal * 1.2, 1.0)),
                            .init(color: .clear, location: min(reveal * 1.2 + 0.15, 1.0)),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height)
                }
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    reveal = 1
                }
            }
    }
}
