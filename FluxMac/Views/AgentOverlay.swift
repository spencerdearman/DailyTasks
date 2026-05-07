//
//  AgentOverlay.swift
//  FluxMac
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
    @EnvironmentObject private var weatherService: FluxWeatherService
    @AppStorage("geminiAPIKey") private var apiKey = ""

    let onDismiss: () -> Void
    var onSelectTask: ((UUID) -> Void)?

    @State private var agent = TaskAgent()
    @State private var input = ""
    @State private var responses: [AgentResult] = []
    @State private var showPanel = false
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
    }

    var body: some View {
        ZStack {
            Color.black.opacity(showPanel ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .animation(.easeOut(duration: 0.2), value: showPanel)

            GeometryReader { geo in
                VStack(spacing: 0) {
                    searchBar

                    if !responses.isEmpty || agent.isProcessing {
                        resultArea
                            .transition(.identity)
                    }
                }
                .frame(width: 580)
                .background(Color(white: 0.08).opacity(0.6), in: .rect(cornerRadius: 22))
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .shadow(color: .black.opacity(0.35), radius: 40, y: 12)
                .scaleEffect(showPanel ? 1 : 0.97)
                .opacity(showPanel ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, geo.size.height * 0.28)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showPanel = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
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

            if agent.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            }

            if !input.isEmpty && !agent.isProcessing {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            if input.isEmpty && !agent.isProcessing {
                Text("⌘A")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeOut(duration: 0.12), value: input.isEmpty)
        .animation(.easeOut(duration: 0.12), value: agent.isProcessing)
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
                        resultView(result)
                            .id(result.id)
                    }

                    if agent.isProcessing {
                        thinkingView
                            .id("thinking")
                    }
                }
                .padding(.bottom, 10)
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
                    weatherSummary: weatherService.summary
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            } else if let proposal = result.proposal {
                ScheduleProposalCard(proposal: proposal) { option in
                    acceptProposal(proposal: proposal, option: option)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
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
        if cal.isDateInTomorrow(date) { return "Tmrw" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: .now)
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !agent.isProcessing else { return }

        let query = trimmed
        input = ""

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

            withAnimation(.easeOut(duration: 0.25)) {
                responses.append(AgentResult(
                    query: query,
                    text: response.message,
                    taskCards: response.taskCards,
                    eventCards: response.eventCards,
                    subtasks: response.subtasks,
                    isPlanDay: response.isPlanDay,
                    proposal: response.proposal
                ))
            }
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

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
