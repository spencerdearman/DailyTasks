//
//  TaskListScreen.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskListScreen

/// Displays a scrollable list of tasks for a given sidebar category (Inbox, Today, etc.).
struct TaskListScreen: View {

    // MARK: - Properties

    let title: String
    let tasks: [TaskItem]
    var events: [CalendarEvent] = []
    let defaultSelection: SidebarSelection?

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.agentActivity) private var agentActivity
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @AppStorage("geminiAPIKey") private var apiKey = ""

    // MARK: - State

    @State private var showingQuickEntry = false
    @State private var showingNewProject = false
    @State private var showingNewArea = false
    @State private var editingTask: TaskItem?
    @State private var suggestion: AgentSuggestion?
    @State private var suggestionDismissed = false
    @State private var suggestionAgent = TaskAgent()
    @State private var suggestionResult: String?
    @State private var suggestionResultTimestamp: Date?
    @State private var eventKitService = EventKitSyncService()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Agent working indicator
                if agentActivity.isWorking {
                    agentWorkingBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Inline agent suggestion
                if let suggestion, !suggestionDismissed {
                    if let resultText = suggestionResult {
                        // Show the result after agent processed
                        InlineSuggestionResultCard(message: resultText) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.suggestionResult = nil
                                self.suggestionDismissed = true
                            }
                        }
                    } else {
                        InlineSuggestionCard(
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
                }

                if !events.isEmpty {
                    EventStrip(events: events)
                }

                if tasks.isEmpty && events.isEmpty {
                    EmptyCard(title: title)
                } else if !tasks.isEmpty {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            TaskCard(task: task) {
                                editingTask = task
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tasks.map(\.id))
                }
            }
            .padding(20)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: agentActivity.isWorking)
        }
        .onAppear {
            if let sel = defaultSelection {
                // Keep existing results for 2 hours before re-indexing
                if let ts = suggestionResultTimestamp,
                   suggestionResult != nil,
                   Date.now.timeIntervalSince(ts) < 2 * 60 * 60 {
                    return
                }

                let suggestions = AgentSuggestionService.suggestions(
                    for: sel, tasks: allTasks, calendarEvents: events
                )
                suggestion = suggestions.first
                suggestionDismissed = false
                suggestionResult = nil
                suggestionResultTimestamp = nil
            }
        }
        .pullToAgent()
        .background(AppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingQuickEntry = true } label: {
                        Label("New Task", systemImage: "checkmark.circle")
                    }
                    Button { showingNewProject = true } label: {
                        Label("New Project", systemImage: "paperplane")
                    }
                    Button { showingNewArea = true } label: {
                        Label("New Area", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            QuickEntrySheet(defaultSelection: defaultSelection)
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectSheet()
        }
        .sheet(isPresented: $showingNewArea) {
            NewAreaSheet()
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }

    // MARK: - Agent Working Banner

    private var agentWorkingBanner: some View {
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
    }

    // MARK: - Suggestion Actions

    private func acceptSuggestion(_ suggestion: AgentSuggestion) {
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
                tasks: allTasks,
                calendarEvents: calEvents,
                eventKitService: eventKitService
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

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                suggestionResult = response.message
                suggestionResultTimestamp = .now
            }
        }
    }
}

// MARK: - InlineSuggestionResultCard

/// Shows the agent's response after a suggestion was accepted.
struct InlineSuggestionResultCard: View {
    let message: String
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var barShimmerActive = false

    private static let agentGradient = LinearGradient(
        colors: [
            Color(red: 0.35, green: 0.28, blue: 0.72).opacity(0.4),
            Color(red: 0.50, green: 0.40, blue: 0.92).opacity(0.25),
            Color(red: 0.45, green: 0.65, blue: 1.0).opacity(0.3)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private func markdownRendered(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Accent edge bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: barShimmerActive
                            ? [Color(red: 0.45, green: 0.65, blue: 1.0).opacity(0.7), Color(red: 0.50, green: 0.40, blue: 0.92).opacity(0.5)]
                            : [Color(red: 0.35, green: 0.28, blue: 0.72).opacity(0.4), Color(red: 0.50, green: 0.40, blue: 0.92).opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 4)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 0.35, green: 0.28, blue: 0.72), Color(red: 0.50, green: 0.40, blue: 0.92)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                    Text("AGENT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 0.35, green: 0.28, blue: 0.72), Color(red: 0.50, green: 0.40, blue: 0.92)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                }

                Text(markdownRendered(message))
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Self.agentGradient, lineWidth: 0.5)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                barShimmerActive = true
            }
        }
    }
}
