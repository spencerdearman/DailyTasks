//
//  TaskCollectionView.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskCollectionView

/// A scrollable list of tasks grouped into sections, with optional event display.
struct TaskCollectionView: View {
    @EnvironmentObject private var weatherService: TetherWeatherService
    @EnvironmentObject private var calendarStore: CalendarStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.agentActivity) private var agentActivity
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @AppStorage("geminiAPIKey") private var apiKey = ""

    let title: String
    let tasks: [TaskItem]
    var eveningTasks: [TaskItem] = []
    let events: [CalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (TaskItem) -> Void
    var synthesis: DailySynthesis? = nil
    var onOpenSynthesis: (() -> Void)? = nil
    /// Which sidebar screen this collection is showing — used for inline suggestions.
    var screenType: SidebarSelection? = nil
    /// Task IDs recently affected by the agent — shown with a highlight animation.
    var agentHighlightIDs: Set<UUID> = []

    @State private var suggestion: AgentSuggestion?
    @State private var suggestionDismissed = false
    @State private var suggestionAgent = TaskAgent()
    @State private var suggestionResult: AgentSuggestionResult?

    /// Holds the full result from an accepted inline suggestion.
    struct AgentSuggestionResult {
        let message: String
        let isPlanDay: Bool
        let taskCards: [TaskCard]?
        let eventCards: [EventCard]?
        let timestamp: Date
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Agent working indicator
                if agentActivity.isWorking {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.pulse, isActive: true)
                        ThinkingShimmer()
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Unified agent strip
                let hasAgentContent = suggestionResult != nil || (suggestion != nil && !suggestionDismissed)
                let hasSynthesis = synthesis != nil

                if hasAgentContent || hasSynthesis {
                    AgentStripCard {
                        VStack(alignment: .leading, spacing: 0) {
                            // Agent suggestion or result
                            if let result = suggestionResult {
                                if result.isPlanDay {
                                    // Use the rich plan card for plan-day responses
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(AgentPalette.gradient)
                                            Text("Agent")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(AgentPalette.gradient)
                                                .textCase(.uppercase)
                                                .tracking(0.3)
                                            Spacer()
                                            Button {
                                                withAnimation(.easeOut(duration: 0.25)) {
                                                    self.suggestionResult = nil
                                                }
                                                if let screen = screenType {
                                                    agentActivity.clearCachedResult(for: screen)
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.tertiary)
                                                    .frame(width: 20, height: 20)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.top, 10)
                                        .padding(.bottom, 4)

                                        DailyPlanCard(
                                            message: result.message,
                                            taskCards: result.taskCards,
                                            eventCards: result.eventCards,
                                            weatherSummary: weatherService.summary,
                                            weatherService: weatherService,
                                            onSelectTask: { _ in }
                                        )
                                        .padding(.horizontal, 6)
                                        .padding(.bottom, 6)
                                    }
                                } else {
                                    InlineSuggestionResultCardMac(message: result.message) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            self.suggestionResult = nil
                                        }
                                        if let screen = screenType {
                                            agentActivity.clearCachedResult(for: screen)
                                        }
                                    }
                                }
                            } else if let suggestion, !suggestionDismissed {
                                InlineSuggestionCardMac(
                                    suggestion: suggestion,
                                    isProcessing: suggestionAgent.isProcessing,
                                    onAccept: { acceptSuggestion(suggestion) },
                                    onDismiss: {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            suggestionDismissed = true
                                        }
                                    }
                                )
                            }

                            // Briefing row (compact, inside the agent strip)
                            if let synthesis, hasAgentContent {
                                Divider().opacity(0.15).padding(.horizontal, 12)
                                SynthesisBannerCompact(
                                    synthesis: synthesis,
                                    weatherSummary: weatherService.summary,
                                    onTap: { onOpenSynthesis?() }
                                )
                            }
                        }
                    }

                    // Standalone briefing when there's no agent content above
                    if let synthesis, !hasAgentContent {
                        SynthesisBanner(synthesis: synthesis, weatherSummary: weatherService.summary, onTap: { onOpenSynthesis?() })
                    }
                }

                if !events.isEmpty {
                    EventStrip(events: events)
                }

                if tasks.isEmpty && eveningTasks.isEmpty {
                    EmptyState(title: title)
                } else {
                    TaskSection(
                        title: "Tasks",
                        tasks: tasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs,
                        onToggle: onToggle,
                        agentHighlightIDs: agentHighlightIDs
                    )
                    if !eveningTasks.isEmpty {
                        TaskSection(
                            title: "This Evening",
                            tasks: eveningTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs,
                            onToggle: onToggle,
                            agentHighlightIDs: agentHighlightIDs
                        )
                    }
                }
            }
            .padding(28)
        }
        .onAppear {
            if let screen = screenType {
                // Restore cached result if it's still fresh (< 2 hours)
                if let cached = agentActivity.cachedSuggestionResult(for: screen) {
                    suggestionResult = AgentSuggestionResult(
                        message: cached.message,
                        isPlanDay: cached.isPlanDay,
                        taskCards: cached.taskCards,
                        eventCards: cached.eventCards,
                        timestamp: cached.timestamp
                    )
                    suggestionDismissed = false
                    return
                }

                let suggestions = AgentSuggestionService.suggestions(
                    for: screen, tasks: allTasks, calendarEvents: events
                )
                suggestion = suggestions.first
                suggestionDismissed = false
                suggestionResult = nil
            }
        }
    }

    // MARK: - Suggestion Actions

    private func acceptSuggestion(_ suggestion: AgentSuggestion) {
        Task {
            calendarStore.refresh()
            let ctx = AgentContext(
                modelContext: modelContext,
                calendarStore: calendarStore,
                locationService: nil,
                weatherSummary: weatherService.promptSummary,
                areas: areas,
                projects: projects,
                tasks: allTasks,
                calendarEvents: calendarStore.allEvents
            )

            // Bypass Gemini for categorization — call directly for reliability
            let response: AgentResponse
            if suggestion.kind == .unsortedInbox {
                response = await suggestionAgent.categorizeInbox(apiKey: apiKey, context: ctx)
            } else {
                response = await suggestionAgent.process(
                    suggestion.agentPrompt,
                    apiKey: apiKey,
                    context: ctx
                )
            }

            let result = AgentSuggestionResult(
                message: response.message,
                isPlanDay: response.isPlanDay,
                taskCards: response.taskCards,
                eventCards: response.eventCards,
                timestamp: .now
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                suggestionResult = result
            }

            // Cache so it survives tab switches
            if let screen = screenType {
                agentActivity.cacheSuggestionResult(
                    .init(message: result.message, isPlanDay: result.isPlanDay,
                          taskCards: result.taskCards, eventCards: result.eventCards,
                          timestamp: result.timestamp),
                    for: screen
                )
            }
        }
    }
}

// MARK: - Agent Color Palette

private enum AgentPalette {
    static let deep = Color(red: 0.18, green: 0.12, blue: 0.45)       // midnight indigo
    static let mid = Color(red: 0.30, green: 0.22, blue: 0.65)        // rich violet
    static let lavender = Color(red: 0.45, green: 0.35, blue: 0.80)   // soft lavender
    static let bright = Color(red: 0.55, green: 0.42, blue: 0.92)     // vivid purple
    static let periwinkle = Color(red: 0.48, green: 0.52, blue: 0.95) // periwinkle blue
    static let accent = Color(red: 0.38, green: 0.58, blue: 1.0)      // cornflower blue
    static let sky = Color(red: 0.42, green: 0.72, blue: 1.0)         // sky blue
    static let glow = Color(red: 0.50, green: 0.45, blue: 0.95)       // violet glow

    static let gradient = LinearGradient(
        colors: [mid, lavender, bright],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let wideGradient = LinearGradient(
        colors: [mid, lavender, bright, periwinkle, accent],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let borderGradient = LinearGradient(
        colors: [mid.opacity(0.35), bright.opacity(0.25), periwinkle.opacity(0.2), accent.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - AgentStripCard

/// A container card for agent content with a subtle gradient border and glass background.
struct AgentStripCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AgentPalette.borderGradient, lineWidth: 0.5)
            }
    }
}

// MARK: - InlineSuggestionCardMac

/// Displays a contextual agent suggestion inline on Mac task list screens.
struct InlineSuggestionCardMac: View {
    let suggestion: AgentSuggestion
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var shimmerAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = sin(t * 0.5) * 0.5 + 0.5

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AgentPalette.mid, AgentPalette.bright, AgentPalette.accent],
                            startPoint: UnitPoint(x: CGFloat(phase) * 0.8, y: 0),
                            endPoint: UnitPoint(x: 0.5 + CGFloat(phase) * 0.5, y: 1)
                        )
                    )
                    .symbolEffect(.pulse, isActive: isProcessing)
            }

            if isProcessing {
                // Shimmer text (same style as ThinkingShimmer)
                processingShimmer
            } else {
                Text(suggestion.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.85))
            }

            Spacer()

            Button(action: onAccept) {
                HStack(spacing: 4) {
                    if isProcessing {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .semibold))
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    }
                    Text(isProcessing ? "Working..." : suggestion.actionLabel)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(isProcessing ? AgentPalette.mid : AgentPalette.mid.opacity(0.7))
                }
                .overlay {
                    if isProcessing {
                        GeometryReader { geo in
                            let w = geo.size.width
                            LinearGradient(
                                colors: [
                                    .clear,
                                    AgentPalette.lavender.opacity(0.5),
                                    AgentPalette.accent.opacity(0.6),
                                    AgentPalette.sky.opacity(0.5),
                                    AgentPalette.accent.opacity(0.6),
                                    AgentPalette.lavender.opacity(0.5),
                                    .clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: w * 1.2)
                            .offset(x: shimmerAnimating ? w * 0.8 : -w * 1.2)
                        }
                        .clipShape(Capsule())
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isProcessing)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            if !isProcessing {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onChange(of: isProcessing) { _, working in
            if working {
                shimmerAnimating = false
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        shimmerAnimating = true
                    }
                }
            }
        }
    }

    /// Shimmer text that matches the ThinkingShimmer style.
    private var processingShimmer: some View {
        Text(suggestion.message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary.opacity(0.12))
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            AgentPalette.glow.opacity(0.4),
                            Color.primary.opacity(0.3),
                            AgentPalette.glow.opacity(0.4),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.5)
                    .offset(x: shimmerAnimating ? w : -w * 0.5)
                }
                .mask {
                    Text(suggestion.message)
                        .font(.system(size: 13, weight: .medium))
                }
            }
    }
}

// MARK: - InlineSuggestionResultCardMac

/// Shows the agent's response after a suggestion was accepted (Mac).
struct InlineSuggestionResultCardMac: View {
    let message: String
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var barShimmerActive = false

    private func markdownRendered(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Accent edge — soft diffused glow that breathes
            ZStack {
                // Soft outer glow
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: barShimmerActive
                                ? [AgentPalette.accent.opacity(0.3), AgentPalette.bright.opacity(0.15), AgentPalette.accent.opacity(0.25)]
                                : [AgentPalette.mid.opacity(0.15), AgentPalette.bright.opacity(0.1), AgentPalette.mid.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6)
                    .blur(radius: 3)
                // Sharp inner line
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: barShimmerActive
                                ? [AgentPalette.accent.opacity(0.7), AgentPalette.bright.opacity(0.5), AgentPalette.mid.opacity(0.6)]
                                : [AgentPalette.mid.opacity(0.4), AgentPalette.bright.opacity(0.35), AgentPalette.mid.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.5)
            }
            .frame(width: 8)
            .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AgentPalette.gradient)
                    Text("Tether Agent")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AgentPalette.gradient)
                        .textCase(.uppercase)
                        .tracking(0.3)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }

                Text(markdownRendered(message))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                barShimmerActive = true
            }
        }
    }
}

// MARK: - SynthesisBannerCompact

/// A compact briefing row for use inside the agent strip card.
struct SynthesisBannerCompact: View {
    let synthesis: DailySynthesis
    var weatherSummary: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange.opacity(0.8))

                Text(periodTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if let weather = weatherSummary {
                    Text(weather)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if synthesis.overdueCount > 0 {
                        Text("\(synthesis.overdueCount) overdue")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                    if !synthesis.conflicts.isEmpty {
                        Text("\(synthesis.conflicts.count) conflict\(synthesis.conflicts.count == 1 ? "" : "s")")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var periodTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 12 { return "Morning Briefing" }
        if hour >= 12 && hour < 17 { return "Afternoon Check-In" }
        return "Evening Wrap-Up"
    }
}

// MARK: - Synthesis Banner (Standalone)

/// A standalone card shown at the top of the Today view when a morning briefing is available.
struct SynthesisBanner: View {
    let synthesis: DailySynthesis
    var weatherSummary: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AgentPalette.mid.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AgentPalette.gradient)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(periodTitle)
                            .font(.system(size: 13, weight: .semibold))
                        if let weather = weatherSummary {
                            Text(weather)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(briefingSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    if synthesis.overdueCount > 0 {
                        Text("\(synthesis.overdueCount) overdue")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                    if !synthesis.conflicts.isEmpty {
                        Text("\(synthesis.conflicts.count) conflict\(synthesis.conflicts.count == 1 ? "" : "s")")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AgentPalette.borderGradient, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var periodTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 12 { return "Morning Briefing" }
        if hour >= 12 && hour < 17 { return "Afternoon Check-In" }
        return "Evening Wrap-Up"
    }

    private var briefingSummary: String {
        if !synthesis.greeting.isEmpty {
            let firstSentence = synthesis.greeting.components(separatedBy: ".").first ?? synthesis.greeting
            return String(firstSentence.prefix(80))
        }
        return "Your daily plan is ready"
    }
}
