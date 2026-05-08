//
//  TaskAgent.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Agent Response

struct AgentResponse {
    let message: String
    let affectedTaskIDs: [UUID]
    let subtasks: [String]?
    let taskCards: [AgentTaskCard]?
    let eventCards: [AgentEventCard]?
    let isPlanDay: Bool
    let pendingDeletion: EventDeletion?

    init(
        message: String,
        affectedTaskIDs: [UUID] = [],
        subtasks: [String]? = nil,
        taskCards: [AgentTaskCard]? = nil,
        eventCards: [AgentEventCard]? = nil,
        isPlanDay: Bool = false,
        pendingDeletion: EventDeletion? = nil
    ) {
        self.message = message
        self.affectedTaskIDs = affectedTaskIDs
        self.subtasks = subtasks
        self.taskCards = taskCards
        self.eventCards = eventCards
        self.isPlanDay = isPlanDay
        self.pendingDeletion = pendingDeletion
    }
}

/// A lightweight card representing a task in agent responses.
struct AgentTaskCard: Identifiable {
    let id: UUID
    let title: String
    let project: String?
    let area: String?
    let whenDate: Date?
    let deadline: Date?
    let isCompleted: Bool
}

/// A lightweight card representing a calendar event in agent responses.
struct AgentEventCard: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

/// Represents a pending event deletion awaiting user confirmation.
struct EventDeletion {
    let eventID: String
    let eventTitle: String
    let eventDate: Date
}

// MARK: - Execution Context

struct AgentContext {
    let modelContext: ModelContext
    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let calendarEvents: [CalendarEvent]
    var eventKitService: EventKitSyncService? = nil
    var lastUserInput: String? = nil
}

// MARK: - TaskAgent

@Observable
final class TaskAgent {
    var isProcessing = false
    var lastResponse: AgentResponse?

    private let gemini = GeminiService()
    private let categorizer = CategorizationService()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Actions that mutate tasks (vs read-only actions like list/query/chat).
    private static let mutatingActions: Set<String> = [
        "create_task", "complete_task", "move_task", "schedule_task",
        "defer_task", "create_event", "decompose_task"
    ]

    func process(_ input: String, apiKey: String, context: AgentContext) async -> AgentResponse {
        isProcessing = true
        defer { isProcessing = false }

        var ctx = context
        ctx.lastUserInput = input

        guard !apiKey.isEmpty else {
            let response = keywordFallback(input: input, ctx: ctx)
            lastResponse = response
            return response
        }

        let systemPrompt = buildSystemPrompt(ctx: ctx)

        do {
            let geminiResponse = try await gemini.send(input, apiKey: apiKey, systemPrompt: systemPrompt)
            print("[TaskAgent] Gemini action: \(geminiResponse.action), filter: \(geminiResponse.filter ?? "nil"), message: \(geminiResponse.message ?? "nil")")
            var response = await execute(geminiResponse, ctx: ctx)
            print("[TaskAgent] Response taskCards: \(response.taskCards?.count ?? 0), eventCards: \(response.eventCards?.count ?? 0), isPlanDay: \(response.isPlanDay)")

            // Follow-up loop: if the input looks like multiple commands and Gemini
            // only returned one mutating action, ask it to continue.
            if Self.mutatingActions.contains(geminiResponse.action),
               (geminiResponse.additionalActions ?? []).isEmpty,
               looksLikeMultipleCommands(input) {
                print("[TaskAgent] Multi-command detected, sending follow-up...")
                var allIDs = response.affectedTaskIDs
                var allTaskCards = response.taskCards ?? []
                var allEventCards = response.eventCards ?? []
                let combinedMessage = response.message

                for i in 1...4 {
                    do {
                        let followUp = try await gemini.send(
                            "Continue with the next action from my original request that hasn't been done yet. If everything is complete, use action 'chat'.",
                            apiKey: apiKey,
                            systemPrompt: systemPrompt
                        )
                        print("[TaskAgent] Follow-up \(i): action=\(followUp.action)")

                        guard Self.mutatingActions.contains(followUp.action) else {
                            break
                        }

                        let extra = await executeSingle(followUp, ctx: ctx)
                        allIDs.append(contentsOf: extra.affectedTaskIDs)
                        if let cards = extra.taskCards { allTaskCards.append(contentsOf: cards) }
                        if let events = extra.eventCards { allEventCards.append(contentsOf: events) }
                    } catch {
                        print("[TaskAgent] Follow-up \(i) failed: \(error), stopping follow-ups")
                        break
                    }
                }

                response = AgentResponse(
                    message: combinedMessage,
                    affectedTaskIDs: allIDs,
                    taskCards: allTaskCards.isEmpty ? nil : allTaskCards,
                    eventCards: allEventCards.isEmpty ? nil : allEventCards,
                    isPlanDay: response.isPlanDay
                )
            }

            lastResponse = response
            return response
        } catch let error as DecodingError {
            print("[TaskAgent] JSON decode error: \(error)")
            let response = AgentResponse(message: "I had trouble understanding the AI response. Please try rephrasing your request.")
            lastResponse = response
            return response
        } catch {
            print("[TaskAgent] Gemini error: \(error)")
            let errorMessage: String
            let nsError = error as NSError
            if nsError.code == -1001 || nsError.code == -1009 {
                errorMessage = nsError.code == -1009
                    ? "No internet connection. Please check your network and try again."
                    : "The request timed out. Please try again — shorter, more specific commands work best."
            } else if let geminiError = error as? GeminiError {
                switch geminiError {
                case .apiError(let code, _) where code == 401 || code == 403:
                    errorMessage = "Your API key is invalid or expired. Please update it in Settings."
                case .apiError(let code, _) where code == 429:
                    errorMessage = "Too many requests — the AI service is rate-limited. Please wait a moment and try again."
                case .apiError(let code, _) where code >= 500:
                    errorMessage = "The AI service is temporarily unavailable. Please try again in a moment."
                default:
                    errorMessage = "Something went wrong connecting to the AI service. Please try again."
                }
            } else {
                errorMessage = "Something went wrong connecting to the AI service. Please try again."
            }
            let response = AgentResponse(message: errorMessage)
            lastResponse = response
            return response
        }
    }

    /// Heuristic: does the input contain multiple comma/and-separated commands?
    private func looksLikeMultipleCommands(_ input: String) -> Bool {
        let lower = input.lowercased()
        let actionPatterns = ["move ", "schedule ", "complete ", "add ", "create ", "delete ", "defer ", "get rid", "mark ", "reschedule "]
        let actionCount = actionPatterns.reduce(0) { count, pattern in
            count + lower.components(separatedBy: pattern).count - 1
        }
        return actionCount >= 2
    }

    func clearConversation() async {
        await gemini.clearHistory()
    }

    // MARK: - Execute Gemini Response

    private func execute(_ response: GeminiActionResponse, ctx: AgentContext) async -> AgentResponse {
        let primary = await executeSingle(response, ctx: ctx)

        // Execute any additional actions
        guard let additional = response.additionalActions, !additional.isEmpty else {
            return primary
        }

        var allIDs = primary.affectedTaskIDs
        var allTaskCards = primary.taskCards ?? []
        var allEventCards = primary.eventCards ?? []

        for extra in additional {
            let result = await executeSingle(extra, ctx: ctx)
            allIDs.append(contentsOf: result.affectedTaskIDs)
            if let cards = result.taskCards { allTaskCards.append(contentsOf: cards) }
            if let events = result.eventCards { allEventCards.append(contentsOf: events) }
        }

        return AgentResponse(
            message: primary.message,
            affectedTaskIDs: allIDs,
            taskCards: allTaskCards.isEmpty ? nil : allTaskCards,
            eventCards: allEventCards.isEmpty ? nil : allEventCards,
            isPlanDay: primary.isPlanDay
        )
    }

    private func executeSingle(_ response: GeminiActionResponse, ctx: AgentContext) async -> AgentResponse {
        let message = response.message ?? "Done"

        switch response.action {
        case "create_task":
            return await doCreateTask(response, message: message, ctx: ctx)
        case "complete_task":
            return doCompleteTask(searchText: response.searchText ?? response.title ?? "", message: message, ctx: ctx)
        case "move_task":
            return doMoveTask(searchText: response.searchText ?? "", targetProject: response.targetProject, targetArea: response.targetArea, message: message, ctx: ctx)
        case "schedule_task":
            return doScheduleTask(searchText: response.searchText ?? "", date: response.date ?? "today", message: message, ctx: ctx)
        case "defer_task":
            return doDeferTask(searchText: response.searchText ?? "", message: message, ctx: ctx)
        case "list_tasks":
            return doListTasks(filter: response.filter ?? "today", message: message, ctx: ctx)
        case "create_event":
            return await doCreateEvent(
                title: response.eventTitle ?? response.title ?? "New Event",
                startString: response.eventStart ?? response.date,
                endString: response.eventEnd,
                location: response.eventLocation,
                message: message, ctx: ctx
            )
        case "delete_event":
            return doDeleteEvent(
                searchText: response.searchText ?? response.eventTitle ?? response.title ?? "",
                message: message, ctx: ctx
            )
        case "decompose_task":
            return AgentResponse(message: message, subtasks: response.subtasks)
        case "plan_day":
            return buildPlanDayResponse(message: message, filter: response.filter, ctx: ctx)
        case "reschedule_overdue":
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            let overdue = ctx.tasks.filter { $0.status == .active && ($0.effectiveDate ?? .distantFuture) < today }
            let cards = overdue.prefix(15).map { task in
                AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: false)
            }
            return AgentResponse(message: message, taskCards: cards.isEmpty ? nil : cards)
        case "query", "chat":
            let taskCards = matchTaskCards(message: message, tasks: ctx.tasks)
            return AgentResponse(message: message, taskCards: taskCards.isEmpty ? nil : taskCards)
        default:
            return AgentResponse(message: message)
        }
    }

    // MARK: - Action: Create Task

    private func doCreateTask(_ response: GeminiActionResponse, message: String, ctx: AgentContext) async -> AgentResponse {
        let title = response.title ?? "Untitled"
        var project = response.targetProject.flatMap { findProject(named: $0, in: ctx.projects) }
        var area = response.targetArea.flatMap { findArea(named: $0, in: ctx.areas) } ?? project?.area

        // Check if this should be a "Later" (someday) task
        let isLater = response.date?.lowercased() == "later" || response.date?.lowercased() == "someday"
        let whenDate = isLater ? nil : response.date.flatMap { parseDate($0) }
        let taskStatus: TaskStatus = isLater ? .someday : .active

        // Parse deadline — try ISO datetime first, then date-only with 11:59 PM default
        var deadlineDate: Date? = nil
        if let deadlineStr = response.deadline {
            // Try ISO 8601 datetime (e.g. "2026-05-09T18:32:00")
            let isoFmt = DateFormatter()
            isoFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            isoFmt.timeZone = .current
            if let fullDatetime = isoFmt.date(from: deadlineStr) {
                deadlineDate = fullDatetime
            } else if let dateOnly = parseDate(deadlineStr) {
                let cal = Calendar.current
                deadlineDate = cal.date(bySettingHour: 23, minute: 59, second: 0, of: dateOnly)
            }
        }

        // Fallback: detect "by <day>" in the title when Gemini forgot the deadline field
        if deadlineDate == nil {
            let titleLower = title.lowercased()
            if let byRange = titleLower.range(of: #"\bby\s+(\w+(?:\s+\w+)?)\s*$"#, options: .regularExpression) {
                let dateStr = String(titleLower[byRange]).replacingOccurrences(of: "by ", with: "").trimmingCharacters(in: .whitespaces)
                if let parsed = parseDate(dateStr) {
                    let cal = Calendar.current
                    deadlineDate = cal.date(bySettingHour: 23, minute: 59, second: 0, of: parsed)
                }
            }
        }

        if area == nil && project == nil {
            let classification = await categorizer.categorize(
                title: title,
                notes: response.notes ?? "",
                areas: ctx.areas.map { (name: $0.title, description: $0.notes) },
                projects: ctx.projects.map { (name: $0.title, areaName: $0.area?.title) },
                apiKey: UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
            )
            if let areaName = classification.area {
                area = findArea(named: areaName, in: ctx.areas)
            }
            if let projName = classification.project {
                project = findProject(named: projName, in: ctx.projects)
                if area == nil { area = project?.area }
            }
        }

        let task = TaskItem(
            title: title,
            notes: response.notes ?? "",
            whenDate: whenDate,
            deadline: deadlineDate,
            status: taskStatus,
            isInInbox: area == nil && project == nil,
            area: area,
            project: project
        )
        ctx.modelContext.insert(task)
        try? ctx.modelContext.save()

        let taskCard = AgentTaskCard(id: task.id, title: task.title, project: project?.title, area: area?.title, whenDate: whenDate, deadline: deadlineDate, isCompleted: false)
        return AgentResponse(message: message, affectedTaskIDs: [task.id], taskCards: [taskCard])
    }

    // MARK: - Action: Complete Task

    private func doCompleteTask(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.markComplete()
        try? ctx.modelContext.save()
        let card = AgentTaskCard(id: match.id, title: match.title, project: match.project?.title, area: match.area?.title, whenDate: match.whenDate, deadline: match.deadline, isCompleted: true)
        return AgentResponse(message: message, affectedTaskIDs: [match.id], taskCards: [card])
    }

    // MARK: - Action: Move Task

    private func doMoveTask(searchText: String, targetProject: String?, targetArea: String?, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { !$0.isCompleted }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        let proj = targetProject.flatMap { findProject(named: $0, in: ctx.projects) }
        let area = targetArea.flatMap { findArea(named: $0, in: ctx.areas) } ?? proj?.area
        match.project = proj
        match.area = area
        match.heading = nil
        match.isInInbox = area == nil && proj == nil
        match.updatedAt = .now
        try? ctx.modelContext.save()
        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Schedule Task

    private func doScheduleTask(searchText: String, date: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        // Try the explicit date field first, then fall back to extracting from the message
        let whenDate: Date?
        if let parsed = parseDate(date) {
            whenDate = parsed
        } else if let extracted = extractDateFromMessage(message) {
            whenDate = extracted
        } else {
            whenDate = nil
        }
        guard let whenDate else {
            return AgentResponse(message: "Couldn't understand the date \"\(date)\"")
        }
        match.whenDate = whenDate
        match.updatedAt = .now
        try? ctx.modelContext.save()
        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Defer Task

    private func doDeferTask(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.status = .someday
        match.whenDate = nil
        match.updatedAt = .now
        try? ctx.modelContext.save()
        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Create Event

    private func doCreateEvent(title: String, startString: String?, endString: String?, location: String?, message: String, ctx: AgentContext) async -> AgentResponse {
        guard let eventKit = ctx.eventKitService else {
            return AgentResponse(message: "Calendar access is not available.")
        }

        // Try to parse startString, or fall back to extracting from title / user input
        var startDate: Date?
        if let startStr = startString {
            startDate = parseDatetime(startStr)
        }
        if startDate == nil {
            startDate = parseDatetime(title)
        }
        if startDate == nil, let userInput = ctx.lastUserInput {
            startDate = extractDatetimeFromNaturalLanguage(userInput)
        }

        guard let startDate else {
            return AgentResponse(message: "Couldn't understand the event time. Please try again with a specific date and time.")
        }

        let endDate: Date
        if let endStr = endString, let parsed = parseDatetime(endStr) {
            endDate = parsed
        } else {
            endDate = startDate.addingTimeInterval(3600)
        }

        do {
            let event = try await eventKit.createCalendarEvent(title: title, startDate: startDate, endDate: endDate, location: location)
            let card = AgentEventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: false)
            return AgentResponse(message: message, eventCards: [card])
        } catch {
            return AgentResponse(message: "Failed to create calendar event: \(error.localizedDescription)")
        }
    }

    // MARK: - Action: Delete Event

    private func doDeleteEvent(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let searchLower = searchText.lowercased()
        let matching = ctx.calendarEvents.filter { event in
            event.title.lowercased().contains(searchLower) ||
            searchLower.contains(event.title.lowercased())
        }

        guard let event = matching.first else {
            return AgentResponse(message: "Couldn't find a calendar event matching \"\(searchText)\".")
        }

        let card = AgentEventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
        let deletion = EventDeletion(eventID: event.id, eventTitle: event.title, eventDate: event.startDate)

        return AgentResponse(message: message, eventCards: [card], pendingDeletion: deletion)
    }

    // MARK: - Action: List Tasks

    private func doListTasks(filter: String, message: String, ctx: AgentContext) -> AgentResponse {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = ctx.tasks.filter { $0.status == .active }
        print("[TaskAgent] doListTasks filter: '\(filter)', active tasks: \(active.count), total tasks: \(ctx.tasks.count)")

        let filtered: [TaskItem]

        switch filter.lowercased() {
        case "inbox":
            filtered = active.filter(\.isInInbox)
        case "today":
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return calendar.isDate(d, inSameDayAs: today)
            }
        case "tomorrow":
            guard let tmrw = calendar.date(byAdding: .day, value: 1, to: today) else {
                return AgentResponse(message: message)
            }
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return calendar.isDate(d, inSameDayAs: tmrw)
            }
        case "upcoming":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? .now
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return d >= tomorrow
            }
        case "open":
            filtered = active.filter { !$0.isInInbox && $0.whenDate == nil }
        case "later":
            filtered = ctx.tasks.filter { $0.status == .someday }
        case "done":
            filtered = Array(ctx.tasks.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(10))
        default:
            if let project = findProject(named: filter, in: ctx.projects) {
                filtered = project.taskList.filter { !$0.isCompleted }
            } else if let area = findArea(named: filter, in: ctx.areas) {
                let areaTasks = ctx.tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
                filtered = areaTasks.filter { !$0.isCompleted }
            } else {
                filtered = active.filter { $0.title.localizedCaseInsensitiveContains(filter) }
            }
        }

        print("[TaskAgent] doListTasks found \(filtered.count) tasks for filter '\(filter)'")

        if filtered.isEmpty {
            // For "today" queries with no scheduled tasks, show all active tasks as a helpful fallback
            if filter.lowercased() == "today" && !active.isEmpty {
                let fallbackCards: [AgentTaskCard] = Array(active.prefix(15).map { task in
                    AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
                })
                let fallbackMessage = "No tasks scheduled specifically for today, but here are your active tasks:"
                return AgentResponse(message: fallbackMessage, affectedTaskIDs: active.prefix(15).map(\.id), taskCards: fallbackCards)
            }
            let emptyMessage: String
            switch filter.lowercased() {
            case "inbox": emptyMessage = "Your inbox is empty."
            case "today": emptyMessage = "No tasks scheduled for today."
            case "tomorrow": emptyMessage = "No tasks scheduled for tomorrow."
            case "later": emptyMessage = "No tasks in your Later list."
            case "done": emptyMessage = "No completed tasks yet."
            default: emptyMessage = "No tasks found for \"\(filter)\"."
            }
            return AgentResponse(message: emptyMessage)
        }

        let cards: [AgentTaskCard] = Array(filtered.prefix(15).map { task in
            AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
        })
        return AgentResponse(message: message, affectedTaskIDs: filtered.map(\.id), taskCards: cards)
    }

    // MARK: - Keyword Fallback

    private func keywordFallback(input: String, ctx: AgentContext) -> AgentResponse {
        let lowered = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let active = ctx.tasks.filter { $0.status == .active }

        if lowered.contains("inbox") {
            return listResponse("Inbox", tasks: active.filter(\.isInInbox))
        }
        if lowered.contains("today") {
            let today = Calendar.current.startOfDay(for: .now)
            let todayTasks = active.filter { guard let d = $0.whenDate else { return false }; return Calendar.current.isDate(d, inSameDayAs: today) }
            return listResponse("Today", tasks: todayTasks)
        }
        if lowered.hasPrefix("add ") || lowered.hasPrefix("create ") {
            let prefixLen = lowered.hasPrefix("add ") ? 4 : 7
            let title = String(input.dropFirst(prefixLen)).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                let task = TaskItem(title: title, status: .active, isInInbox: true)
                ctx.modelContext.insert(task)
                try? ctx.modelContext.save()
                return AgentResponse(message: "Created \"\(title)\" in Inbox", affectedTaskIDs: [task.id])
            }
        }

        return AgentResponse(message: "Set up your Gemini API key in Settings to unlock the full agent. Try: \"show today\", \"add <task>\", or ask about a project by name.")
    }

    private func listResponse(_ label: String, tasks: [TaskItem]) -> AgentResponse {
        if tasks.isEmpty {
            return AgentResponse(message: "No tasks in \(label)")
        }
        let cards = tasks.prefix(15).map { task in
            AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
        }
        return AgentResponse(message: "\(label) — \(tasks.count) task(s)", taskCards: Array(cards))
    }

    // MARK: - Plan Day Response

    private func buildPlanDayResponse(message: String, filter: String?, ctx: AgentContext) -> AgentResponse {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let isTomorrow = filter?.lowercased() == "tomorrow"
        let targetDate = isTomorrow ? cal.date(byAdding: .day, value: 1, to: today)! : today
        let active = ctx.tasks.filter { $0.status == .active }

        let targetTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return cal.isDate(d, inSameDayAs: targetDate)
        }
        let overdueTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return d < today
        }
        let inboxTasks = active.filter(\.isInInbox)

        var allRelevant: [TaskItem] = []
        allRelevant.append(contentsOf: overdueTasks)
        allRelevant.append(contentsOf: targetTasks)
        if !isTomorrow {
            allRelevant.append(contentsOf: inboxTasks.filter { t in
                !overdueTasks.contains(where: { $0.id == t.id }) &&
                !targetTasks.contains(where: { $0.id == t.id })
            })
        }

        let taskCards: [AgentTaskCard]? = allRelevant.isEmpty ? nil : Array(allRelevant.prefix(15).map { task in
            AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
        })

        return AgentResponse(message: message, affectedTaskIDs: allRelevant.map(\.id), taskCards: taskCards, isPlanDay: true)
    }

    // MARK: - Card Matching

    private func matchTaskCards(message: String, tasks: [TaskItem]) -> [AgentTaskCard] {
        let messageLower = message.lowercased()
        return tasks.filter { task in
            messageLower.contains(task.title.lowercased())
        }.prefix(10).map { task in
            AgentTaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
        }
    }

    // MARK: - Helpers

    private func bestMatch(for searchText: String, in tasks: [TaskItem]) -> TaskItem? {
        let lowered = searchText.lowercased()
        if let exact = tasks.first(where: { $0.title.lowercased() == lowered }) { return exact }
        if let hit = tasks.first(where: { $0.title.localizedCaseInsensitiveContains(lowered) }) { return hit }
        let searchWords = Set(lowered.split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !searchWords.isEmpty else { return nil }
        let scored = tasks.compactMap { task -> (TaskItem, Int)? in
            let titleWords = Set(task.title.lowercased().split(separator: " ").map(String.init))
            let overlap = titleWords.intersection(searchWords).count
            return overlap > 0 ? (task, overlap) : nil
        }
        return scored.max(by: { $0.1 < $1.1 })?.0
    }

    private func findArea(named name: String, in areas: [Area]) -> Area? {
        guard !name.isEmpty else { return nil }
        if let exact = areas.first(where: { $0.title.lowercased() == name.lowercased() }) { return exact }
        return areas.first { $0.title.localizedCaseInsensitiveContains(name) }
    }

    private func findProject(named name: String, in projects: [Project]) -> Project? {
        guard !name.isEmpty else { return nil }
        if let exact = projects.first(where: { $0.title.lowercased() == name.lowercased() }) { return exact }
        return projects.first { $0.title.localizedCaseInsensitiveContains(name) }
    }

    private func parseDatetime(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // ISO 8601 (YYYY-MM-DDTHH:mm:ss)
        let localIso = DateFormatter()
        localIso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localIso.timeZone = .current
        if let date = localIso.date(from: trimmed) { return date }

        // YYYY-MM-DD HH:mm
        let spaceFmt = DateFormatter()
        spaceFmt.dateFormat = "yyyy-MM-dd HH:mm"
        spaceFmt.timeZone = .current
        if let date = spaceFmt.date(from: trimmed) { return date }

        // Time-only: "7:00 PM", "3pm"
        let timeFormats = ["h:mm a", "h:mma", "ha", "h a", "HH:mm"]
        for fmt in timeFormats {
            let tf = DateFormatter()
            tf.dateFormat = fmt
            tf.timeZone = .current
            if let time = tf.date(from: trimmed) {
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: time)
                return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: Date())
            }
        }

        // "tomorrow at 3pm", "today at 7:00 PM"
        let prefixPattern = #"^(today|tomorrow|tonight)\s*(?:(?:at|night|evening)\s*)?(.*)$"#
        if let regex = try? NSRegularExpression(pattern: prefixPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let dayRange = Range(match.range(at: 1), in: trimmed) {
            let dayStr = String(trimmed[dayRange]).lowercased()
            let baseDate = parseDate(dayStr == "tonight" ? "today" : dayStr) ?? Calendar.current.startOfDay(for: .now)

            if let timeRange = Range(match.range(at: 2), in: trimmed) {
                let timeStr = String(trimmed[timeRange]).trimmingCharacters(in: .whitespaces)
                if !timeStr.isEmpty, let timeOnly = parseDatetime(timeStr) {
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.hour, .minute], from: timeOnly)
                    return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: baseDate)
                }
            }

            if dayStr == "tonight" || trimmed.lowercased().contains("night") {
                return Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: baseDate)
            }
        }

        return parseDate(trimmed)
    }

    private func extractDatetimeFromNaturalLanguage(_ text: String) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        var baseDate: Date?
        if lower.contains("tonight") || lower.contains("today") {
            baseDate = today
        } else if lower.contains("tomorrow") {
            baseDate = cal.date(byAdding: .day, value: 1, to: today)
        } else {
            let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            for (idx, day) in weekdays.enumerated() {
                if lower.contains(day) {
                    let targetDay = idx + 1
                    let currentDay = cal.component(.weekday, from: today)
                    let daysAhead = (targetDay - currentDay + 7) % 7
                    baseDate = cal.date(byAdding: .day, value: daysAhead == 0 ? 7 : daysAhead, to: today)
                    break
                }
            }
        }
        if baseDate == nil { baseDate = today }

        let timePattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text) {
            var hour = Int(text[hourRange]) ?? 0
            let minute: Int = {
                if let minRange = Range(match.range(at: 2), in: text) { return Int(text[minRange]) ?? 0 }
                return 0
            }()
            if let ampmRange = Range(match.range(at: 3), in: text) {
                let ampm = String(text[ampmRange]).lowercased()
                if ampm == "pm" && hour < 12 { hour += 12 }
                if ampm == "am" && hour == 12 { hour = 0 }
            }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate!)
        }

        if lower.contains("tonight") || lower.contains("evening") || lower.contains("dinner") {
            return cal.date(bySettingHour: 19, minute: 0, second: 0, of: baseDate!)
        }

        return nil
    }

    private func parseDate(_ string: String) -> Date? {
        let lowered = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        switch lowered {
        case "today", "now": return today
        case "tomorrow": return calendar.date(byAdding: .day, value: 1, to: today)
        case "next week": return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
        default:
            let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            // Handle "next <weekday>" — always jumps to next week's instance
            if lowered.hasPrefix("next ") {
                let dayName = String(lowered.dropFirst(5))
                if let idx = weekdays.firstIndex(of: dayName) {
                    let targetDay = idx + 1
                    let currentDay = calendar.component(.weekday, from: today)
                    let daysAhead = (targetDay - currentDay + 7) % 7
                    let offset = daysAhead == 0 ? 7 : daysAhead
                    return calendar.date(byAdding: .day, value: offset, to: today)
                }
            }
            // Handle bare weekday names
            if let idx = weekdays.firstIndex(of: lowered) {
                let targetDay = idx + 1
                let currentDay = calendar.component(.weekday, from: today)
                let daysAhead = (targetDay - currentDay + 7) % 7
                let offset = daysAhead == 0 ? 7 : daysAhead
                return calendar.date(byAdding: .day, value: offset, to: today)
            }
            // Try "May 11", "May 11th", "March 3rd" etc.
            let monthDayFmt = DateFormatter()
            monthDayFmt.locale = Locale(identifier: "en_US")
            let cleaned = lowered
                .replacingOccurrences(of: "\\b(\\d+)(st|nd|rd|th)\\b", with: "$1", options: .regularExpression)
            for fmt in ["MMMM d", "MMM d", "MMMM d, yyyy", "MMM d, yyyy"] {
                monthDayFmt.dateFormat = fmt
                if let date = monthDayFmt.date(from: cleaned) {
                    let year = calendar.component(.year, from: today)
                    var components = calendar.dateComponents([.month, .day], from: date)
                    components.year = year
                    if let result = calendar.date(from: components), result >= today {
                        return result
                    }
                    components.year = year + 1
                    return calendar.date(from: components)
                }
            }
            return dateFormatter.date(from: lowered)
        }
    }

    /// Tries to extract a date from natural language in the message (e.g. "scheduled for *Monday, May 11th*").
    private func extractDateFromMessage(_ message: String) -> Date? {
        let stripped = message.replacingOccurrences(of: "*", with: "")

        // Try weekday names first
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for day in weekdays {
            if stripped.localizedCaseInsensitiveContains(day) {
                return parseDate(day)
            }
        }

        // Try "May 11", "May 11th" etc.
        let monthPattern = #"(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?"#
        if let regex = try? NSRegularExpression(pattern: monthPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: stripped, range: NSRange(stripped.startIndex..., in: stripped)),
           let range = Range(match.range, in: stripped) {
            return parseDate(String(stripped[range]))
        }

        // Try "tomorrow", "next week"
        if stripped.localizedCaseInsensitiveContains("tomorrow") { return parseDate("tomorrow") }
        if stripped.localizedCaseInsensitiveContains("next week") { return parseDate("next week") }

        return nil
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(ctx: AgentContext) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd (EEEE)"
        let todayStr = fmt.string(from: Date())

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let completedTasks = ctx.tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let somedayTasksList = ctx.tasks.filter { $0.status == .someday }

        return GeminiPromptBuilder.buildSystemPrompt(
            areas: ctx.areas.map { (name: $0.title, symbol: $0.symbolName) },
            projects: ctx.projects.map { (name: $0.title, areaName: $0.area?.title) },
            activeTasks: ctx.tasks.filter { $0.status == .active }.map { task in
                (
                    title: task.title,
                    project: task.project?.title,
                    area: task.area?.title,
                    whenDate: task.whenDate.map { dateFmt.string(from: $0) },
                    deadline: task.deadline.map { dateFmt.string(from: $0) },
                    isInInbox: task.isInInbox
                )
            },
            completedTasks: completedTasks.map { task in
                (
                    title: task.title,
                    completedAt: task.completedAt.map { dateFmt.string(from: $0) }
                )
            },
            somedayTasks: somedayTasksList.map { task in
                (
                    title: task.title,
                    project: task.project?.title,
                    area: task.area?.title
                )
            },
            todayDate: todayStr
        )
    }
}
