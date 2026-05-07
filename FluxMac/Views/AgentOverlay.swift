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
    @AppStorage("geminiAPIKey") private var apiKey = ""

    let onDismiss: () -> Void

    @State private var agent = TaskAgent()
    @State private var input = ""
    @State private var messages: [ChatMessage] = []
    @State private var showPanel = false
    @FocusState private var isFocused: Bool

    // MARK: - Message Model

    private struct ChatMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let text: String
        let subtasks: [String]?
        let taskCards: [TaskCard]?
        let eventCards: [EventCard]?
        let timestamp = Date()

        enum MessageRole {
            case user
            case agent
            case thinking
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(showPanel ? 0.2 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .animation(.easeOut(duration: 0.2), value: showPanel)

            // Main panel — centered like Spotlight
            VStack(spacing: 0) {
                searchBar

                if !messages.isEmpty {
                    Divider()
                        .opacity(0.5)
                        .padding(.horizontal, 16)

                    messagesArea
                }
            }
            .frame(width: 600)
            .glassEffect(.regular, in: .rect(cornerRadius: messages.isEmpty ? 28 : 24))
            .shadow(color: .black.opacity(0.3), radius: 50, y: 16)
            .scaleEffect(showPanel ? 1 : 0.96)
            .opacity(showPanel ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: messages.isEmpty)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: agent.isProcessing)

            TextField("Ask Flux anything...", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .light))
                .focused($isFocused)
                .onSubmit { submit() }

            if agent.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            } else {
                Text("⌘A")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            if !input.isEmpty {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .animation(.easeOut(duration: 0.15), value: input.isEmpty)
        .animation(.easeOut(duration: 0.15), value: agent.isProcessing)
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        messageView(message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 420)
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 8)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 4)
                }
            )
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Views

    @ViewBuilder
    private func messageView(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            userBubble(message.text)
        case .agent:
            agentBubble(message)
        case .thinking:
            thinkingIndicator
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 80)
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func agentBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 8) {
                // Strip bullet-point lines from text if we have cards
                let displayText = strippedMessage(message.text, hasCards: message.taskCards != nil || message.eventCards != nil)
                if !displayText.isEmpty {
                    Text(markdownString(displayText))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.9))
                        .textSelection(.enabled)
                        .lineSpacing(2)
                }

                // Event cards
                if let events = message.eventCards, !events.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(events) { event in
                            eventCardView(event)
                        }
                    }
                    .padding(.top, 2)
                }

                // Task cards
                if let tasks = message.taskCards, !tasks.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(tasks) { task in
                            taskCardView(task)
                        }
                    }
                    .padding(.top, 2)
                }

                // Subtask cards
                if let subtasks = message.subtasks, !subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(subtasks.enumerated()), id: \.offset) { _, subtask in
                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                Text(subtask)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 40)
        }
    }

    // MARK: - Card Views

    private func taskCardView(_ task: TaskCard) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(task.isCompleted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))
                    .strikethrough(task.isCompleted, color: .secondary)

                HStack(spacing: 6) {
                    if let project = task.project {
                        Label(project, systemImage: "paperplane")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if let area = task.area {
                        Text(area)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    if let date = task.whenDate ?? task.deadline {
                        Text(formatRelativeDate(date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isOverdue(date) ? .red : .secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func eventCardView(_ event: EventCard) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))

                HStack(spacing: 4) {
                    Text(formatEventTime(event))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Image(systemName: "location.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .symbolEffect(.pulse)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: agent.isProcessing
                        )
                }
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    private func strippedMessage(_ text: String, hasCards: Bool) -> String {
        guard hasCards else { return text }
        // Remove bullet-point lines since we're showing cards instead
        let lines = text.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("·") && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("- ")
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: .now)
    }

    private func formatEventTime(_ event: EventCard) -> String {
        let calendar = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        let dayPrefix: String
        if calendar.isDateInToday(event.startDate) {
            dayPrefix = "Today"
        } else if calendar.isDateInTomorrow(event.startDate) {
            dayPrefix = "Tomorrow"
        } else {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEE"
            dayPrefix = dayFmt.string(from: event.startDate)
        }

        return "\(dayPrefix) \(timeFmt.string(from: event.startDate)) – \(timeFmt.string(from: event.endDate))"
    }

    // MARK: - Actions

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !agent.isProcessing else { return }

        let query = trimmed
        input = ""

        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(ChatMessage(role: .user, text: query, subtasks: nil, taskCards: nil, eventCards: nil))
            messages.append(ChatMessage(role: .thinking, text: "", subtasks: nil, taskCards: nil, eventCards: nil))
        }

        Task {
            let response = await agent.process(
                query,
                apiKey: apiKey,
                context: modelContext,
                areas: areas,
                projects: projects,
                tasks: tasks,
                calendarEvents: calendarStore.allEvents
            )

            withAnimation(.easeOut(duration: 0.25)) {
                messages.removeAll { $0.role == .thinking }
                messages.append(ChatMessage(
                    role: .agent,
                    text: response.message,
                    subtasks: response.subtasks,
                    taskCards: response.taskCards,
                    eventCards: response.eventCards
                ))
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
