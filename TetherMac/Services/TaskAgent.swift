//
//  TaskAgent.swift
//  TetherMac
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
    let taskCards: [TaskCard]?
    let eventCards: [EventCard]?
    let isPlanDay: Bool
    let proposal: ScheduleProposal?
    let pendingDeletion: EventDeletion?

    init(message: String, affectedTaskIDs: [UUID] = [], subtasks: [String]? = nil, taskCards: [TaskCard]? = nil, eventCards: [EventCard]? = nil, isPlanDay: Bool = false, proposal: ScheduleProposal? = nil, pendingDeletion: EventDeletion? = nil) {
        self.message = message
        self.affectedTaskIDs = affectedTaskIDs
        self.subtasks = subtasks
        self.taskCards = taskCards
        self.eventCards = eventCards
        self.isPlanDay = isPlanDay
        self.proposal = proposal
        self.pendingDeletion = pendingDeletion
    }
}

/// A schedule proposal with alternative time slots when a conflict is detected.
struct ScheduleProposal {
    let eventTitle: String
    let originalStart: Date?
    let originalEnd: Date?
    let conflictDescription: String
    let suggestions: [ScheduleOption]
}

struct ScheduleOption: Identifiable {
    let id = UUID()
    let label: String
    let startDate: Date
    let endDate: Date
    let reason: String
    let location: String?
}

struct TaskCard: Identifiable {
    let id: UUID
    let title: String
    let project: String?
    let area: String?
    let whenDate: Date?
    let deadline: Date?
    let isCompleted: Bool
}

struct EventCard: Identifiable {
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

/// Bundles all dependencies the agent needs to execute actions.
/// Add new system capabilities here — all action methods receive this automatically.
struct AgentContext {
    let modelContext: ModelContext
    let calendarStore: CalendarStore?
    let locationService: LocationService?
    let weatherSummary: String?
    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let calendarEvents: [CalendarEvent]
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

    /// Convenience overload that constructs an `AgentContext` from individual parameters.
    func process(
        _ input: String,
        apiKey: String,
        context modelContext: ModelContext,
        areas: [Area],
        projects: [Project],
        tasks: [TaskItem],
        calendarEvents: [CalendarEvent],
        calendarStore: CalendarStore?
    ) async -> AgentResponse {
        let ctx = AgentContext(
            modelContext: modelContext,
            calendarStore: calendarStore,
            locationService: nil,
            weatherSummary: nil,
            areas: areas,
            projects: projects,
            tasks: tasks,
            calendarEvents: calendarEvents
        )
        return await process(input, apiKey: apiKey, context: ctx)
    }

    /// Actions that mutate tasks (vs read-only actions like list/query/chat).
    private static let mutatingActions: Set<String> = [
        "create_task", "complete_task", "move_task", "schedule_task",
        "defer_task", "create_event", "decompose_task"
    ]

    func process(_ input: String, apiKey: String, context: AgentContext) async -> AgentResponse {
        print("[TaskAgent] process called with input: \"\(input)\", apiKey empty: \(apiKey.isEmpty)")
        isProcessing = true
        defer {
            isProcessing = false
            print("[TaskAgent] isProcessing set to false")
        }

        var ctx = context
        ctx.lastUserInput = input

        guard !apiKey.isEmpty else {
            print("[TaskAgent] No API key, using keyword fallback")
            let response = keywordFallback(input: input, ctx: ctx)
            lastResponse = response
            return response
        }

        let systemPrompt = buildSystemPrompt(ctx: ctx)
        print("[TaskAgent] System prompt built (\(systemPrompt.count) chars), calling Gemini...")

        do {
            let geminiResponse = try await gemini.send(input, apiKey: apiKey, systemPrompt: systemPrompt)
            print("[TaskAgent] Gemini returned action: \(geminiResponse.action), message: \(geminiResponse.message ?? "nil")")
            var response = await execute(geminiResponse, ctx: ctx)
            print("[TaskAgent] Executed action, final message: \(response.message.prefix(100))")

            // Follow-up loop: if the input looks like multiple commands and Gemini
            // only returned one mutating action (no additional_actions), ask it to continue.
            if Self.mutatingActions.contains(geminiResponse.action),
               (geminiResponse.additionalActions ?? []).isEmpty,
               looksLikeMultipleCommands(input) {
                print("[TaskAgent] Multi-command detected, sending follow-up...")
                var allIDs = response.affectedTaskIDs
                var allTaskCards = response.taskCards ?? []
                var allEventCards = response.eventCards ?? []
                let combinedMessage = response.message

                // Up to 4 follow-ups to handle remaining commands
                for i in 1...4 {
                    do {
                        let followUp = try await gemini.send(
                            "Continue with the next action from my original request that hasn't been done yet. If everything is complete, use action 'chat'.",
                            apiKey: apiKey,
                            systemPrompt: systemPrompt
                        )
                        print("[TaskAgent] Follow-up \(i): action=\(followUp.action)")

                        guard Self.mutatingActions.contains(followUp.action) else {
                            break // No more actions to take
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
                    isPlanDay: response.isPlanDay,
                    proposal: response.proposal
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
            print("[TaskAgent] ERROR from Gemini: \(error)")
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
        // Count action verbs (move, schedule, complete, add, create, delete, defer, get rid)
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
        var messages = [primary.message]

        for extra in additional {
            let result = await executeSingle(extra, ctx: ctx)
            allIDs.append(contentsOf: result.affectedTaskIDs)
            if let cards = result.taskCards { allTaskCards.append(contentsOf: cards) }
            if let events = result.eventCards { allEventCards.append(contentsOf: events) }
            messages.append(result.message)
        }

        // Use the primary message (which should describe all actions)
        return AgentResponse(
            message: primary.message,
            affectedTaskIDs: allIDs,
            taskCards: allTaskCards.isEmpty ? nil : allTaskCards,
            eventCards: allEventCards.isEmpty ? nil : allEventCards,
            isPlanDay: primary.isPlanDay,
            proposal: primary.proposal
        )
    }

    private func executeSingle(_ response: GeminiActionResponse, ctx: AgentContext) async -> AgentResponse {
        let message = response.message ?? "Done"

        switch response.action {
        case "create_task":
            return await doCreateTask(response, message: message, ctx: ctx)

        case "complete_task":
            return doCompleteTask(
                searchText: response.searchText ?? response.title ?? "",
                message: message, ctx: ctx
            )

        case "move_task":
            return doMoveTask(
                searchText: response.searchText ?? "",
                targetProject: response.targetProject,
                targetArea: response.targetArea,
                message: message, ctx: ctx
            )

        case "schedule_task":
            return doScheduleTask(
                searchText: response.searchText ?? "",
                date: response.date ?? "today",
                message: message, ctx: ctx
            )

        case "defer_task":
            return doDeferTask(
                searchText: response.searchText ?? "",
                message: message, ctx: ctx
            )

        case "list_tasks":
            return doListTasks(
                filter: response.filter ?? "today",
                message: message, ctx: ctx
            )

        case "create_event":
            print("[TaskAgent] create_event raw fields — eventTitle: \(response.eventTitle ?? "nil"), eventStart: \(response.eventStart ?? "nil"), eventEnd: \(response.eventEnd ?? "nil"), date: \(response.date ?? "nil"), title: \(response.title ?? "nil")")
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
            // Show overdue tasks
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            let overdue = ctx.tasks.filter {
                $0.status == .active && ($0.effectiveDate ?? .distantFuture) < today
            }
            let cards = overdue.prefix(15).map { task in
                TaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: false)
            }
            return AgentResponse(message: message, taskCards: cards.isEmpty ? nil : cards)

        case "propose_reschedule":
            return buildProposal(response, message: message, ctx: ctx)

        case "query", "chat":
            let eventCards = matchCalendarEvents(message: message, calendarEvents: ctx.calendarEvents)
            let taskCards = matchTaskCards(message: message, tasks: ctx.tasks)
            return AgentResponse(
                message: message,
                taskCards: taskCards.isEmpty ? nil : taskCards,
                eventCards: eventCards.isEmpty ? nil : eventCards
            )

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

        // Parse deadline — try full datetime first, then date-only with 11:59 PM default
        var deadlineDate: Date? = nil
        if let deadlineStr = response.deadline {
            if let fullDatetime = parseDatetime(deadlineStr) {
                // If Gemini sent a full ISO datetime, use it directly
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

        // Auto-categorize if Gemini didn't assign area/project
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
            if area != nil || project != nil {
                print("[TaskAgent] Auto-categorized '\(title)' → area: \(area?.title ?? "nil"), project: \(project?.title ?? "nil")")
            }
        }

        let task = TaskItem(
            title: title,
            notes: response.notes ?? "",
            whenDate: whenDate,
            deadline: deadlineDate,
            status: taskStatus,
            isInInbox: area == nil && project == nil,
            locationName: response.locationName,
            area: area,
            project: project
        )
        ctx.modelContext.insert(task)
        try? ctx.modelContext.save()

        let taskCard = TaskCard(id: task.id, title: task.title, project: project?.title, area: area?.title, whenDate: whenDate, deadline: deadlineDate, isCompleted: false)
        var eventCards: [EventCard]? = nil

        // If Gemini says to also add to calendar, create the event
        if response.addToCalendar == true, let calendarStore = ctx.calendarStore {
            let startDate = parseDatetime(response.eventStart ?? "") ?? whenDate ?? Date()
            let endDate: Date
            if let endStr = response.eventEnd, let parsed = parseDatetime(endStr) {
                endDate = parsed
            } else {
                endDate = startDate.addingTimeInterval(3600)
            }

            do {
                let event = try await calendarStore.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    location: response.eventLocation
                )
                eventCards = [EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: false)]
                print("[TaskAgent] Also created calendar event for task: \(title)")
            } catch {
                print("[TaskAgent] Failed to create calendar event alongside task: \(error)")
            }
        }

        return AgentResponse(message: message, affectedTaskIDs: [task.id], taskCards: [taskCard], eventCards: eventCards)
    }

    // MARK: - Action: Complete Task

    private func doCompleteTask(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.markComplete()
        try? ctx.modelContext.save()
        let card = TaskCard(id: match.id, title: match.title, project: match.project?.title, area: match.area?.title, whenDate: match.whenDate, deadline: match.deadline, isCompleted: true)
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

    // MARK: - Action: Create Calendar Event

    private func doCreateEvent(title: String, startString: String?, endString: String?, location: String?, message: String, ctx: AgentContext) async -> AgentResponse {
        guard let calendarStore = ctx.calendarStore else {
            return AgentResponse(message: "Calendar access is not available.")
        }

        print("[TaskAgent] doCreateEvent: startString=\(startString ?? "nil"), endString=\(endString ?? "nil"), location=\(location ?? "nil")")

        // Try to parse startString, or fall back to extracting datetime from the title
        var startDate: Date?
        if let startStr = startString {
            startDate = parseDatetime(startStr)
        }

        // Fallback: parse datetime from the title (e.g. "Dinner Event Tomorrow at 7 PM")
        if startDate == nil {
            startDate = parseDatetime(title)
            print("[TaskAgent] doCreateEvent: Fell back to parsing title, got: \(startDate?.description ?? "nil")")
        }

        // Last resort: extract time from the user's original message via conversation context
        if startDate == nil, let lastUserInput = ctx.lastUserInput {
            startDate = extractDatetimeFromNaturalLanguage(lastUserInput)
            print("[TaskAgent] doCreateEvent: Fell back to user input '\(lastUserInput)', got: \(startDate?.description ?? "nil")")
        }

        guard let startDate else {
            print("[TaskAgent] doCreateEvent: All parsing attempts failed")
            return AgentResponse(message: "Couldn't understand the event time. Please try again with a specific date and time.")
        }

        let endDate: Date
        if let endStr = endString, let parsed = parseDatetime(endStr) {
            endDate = parsed
        } else {
            endDate = startDate.addingTimeInterval(3600)
        }

        do {
            let event = try await calendarStore.createEvent(title: title, startDate: startDate, endDate: endDate, location: location)
            let card = EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: false)
            return AgentResponse(message: message, eventCards: [card])
        } catch {
            print("[TaskAgent] Failed to create calendar event: \(error)")
            return AgentResponse(message: "Failed to create calendar event: \(error.localizedDescription)")
        }
    }

    // MARK: - Action: Delete Event

    private func doDeleteEvent(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        // Find matching calendar event
        let searchLower = searchText.lowercased()
        let matching = ctx.calendarEvents.filter { event in
            event.title.lowercased().contains(searchLower) ||
            searchLower.contains(event.title.lowercased())
        }

        guard let event = matching.first else {
            return AgentResponse(message: "Couldn't find a calendar event matching \"\(searchText)\".")
        }

        let card = EventCard(
            id: event.id, title: event.title,
            startDate: event.startDate, endDate: event.endDate,
            location: event.location, isAllDay: event.isAllDay
        )
        let deletion = EventDeletion(
            eventID: event.id,
            eventTitle: event.title,
            eventDate: event.startDate
        )

        return AgentResponse(
            message: message,
            eventCards: [card],
            pendingDeletion: deletion
        )
    }

    // MARK: - Action: List Tasks

    private func doListTasks(filter: String, message: String, ctx: AgentContext) -> AgentResponse {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = ctx.tasks.filter { $0.status == .active }

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

        // Build event cards for calendar-related filters
        let eventCards: [EventCard]?
        let filterLower = filter.lowercased()
        if filterLower == "today" || filterLower == "tomorrow" || filterLower == "upcoming" {
            let matchingEvents: [CalendarEvent]
            if filterLower == "today" {
                matchingEvents = ctx.calendarEvents.filter { calendar.isDateInToday($0.startDate) }
            } else if filterLower == "tomorrow" {
                matchingEvents = ctx.calendarEvents.filter { calendar.isDateInTomorrow($0.startDate) }
            } else {
                matchingEvents = ctx.calendarEvents
            }
            eventCards = matchingEvents.isEmpty ? nil : matchingEvents.map { event in
                EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
            }
        } else {
            eventCards = nil
        }

        if filtered.isEmpty && eventCards == nil {
            print("[TaskAgent] doListTasks: no local tasks matched filter '\(filter)'")
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

        let cards: [TaskCard]? = filtered.isEmpty ? nil : Array(filtered.prefix(15).map { task in
            TaskCard(
                id: task.id, title: task.title, project: task.project?.title,
                area: task.area?.title, whenDate: task.whenDate,
                deadline: task.deadline, isCompleted: task.isCompleted
            )
        })
        print("[TaskAgent] doListTasks: returning \(cards?.count ?? 0) task cards, \(eventCards?.count ?? 0) event cards")
        return AgentResponse(message: message, affectedTaskIDs: filtered.map(\.id), taskCards: cards, eventCards: eventCards)
    }

    // MARK: - Keyword Fallback (no API key)

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
        if lowered.contains("tomorrow") {
            let tmrw = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
            let tmrwTasks = active.filter { guard let d = $0.whenDate else { return false }; return Calendar.current.isDate(d, inSameDayAs: tmrw) }
            return listResponse("Tomorrow", tasks: tmrwTasks)
        }
        if lowered.contains("done") || lowered.contains("completed") {
            let done = Array(ctx.tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.prefix(10))
            return listResponse("Done (recent)", tasks: done)
        }

        for project in ctx.projects {
            if lowered.contains(project.title.lowercased()) {
                return listResponse(project.title, tasks: project.taskList.filter { !$0.isCompleted })
            }
        }
        for area in ctx.areas {
            if lowered.contains(area.title.lowercased()) {
                let areaTasks = ctx.tasks.filter { ($0.area?.id == area.id || $0.project?.area?.id == area.id) && !$0.isCompleted }
                return listResponse(area.title, tasks: areaTasks)
            }
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

        return AgentResponse(message: "Set up your Gemini API key in Settings to unlock the full agent. For now, try: \"show today\", \"add <task>\", or ask about a project by name.")
    }

    private func listResponse(_ label: String, tasks: [TaskItem]) -> AgentResponse {
        if tasks.isEmpty {
            return AgentResponse(message: "No tasks in \(label)")
        }
        let lines = tasks.prefix(15).map { "  · \($0.title)" }.joined(separator: "\n")
        return AgentResponse(message: "\(label) — \(tasks.count) task(s):\n\(lines)", affectedTaskIDs: tasks.map(\.id))
    }

    // MARK: - Plan Day Response

    private func buildPlanDayResponse(message: String, filter: String?, ctx: AgentContext) -> AgentResponse {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let isTomorrow = filter?.lowercased() == "tomorrow"
        let targetDate = isTomorrow ? cal.date(byAdding: .day, value: 1, to: today)! : today
        let active = ctx.tasks.filter { $0.status == .active }

        // Target day's tasks
        let targetTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return cal.isDate(d, inSameDayAs: targetDate)
        }

        // Overdue tasks
        let overdueTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return d < today
        }

        // Inbox tasks (unsorted)
        let inboxTasks = active.filter(\.isInInbox)

        // Combine: overdue first, then target day, then inbox (only for today)
        var allRelevant: [TaskItem] = []
        allRelevant.append(contentsOf: overdueTasks)
        allRelevant.append(contentsOf: targetTasks)
        if !isTomorrow {
            allRelevant.append(contentsOf: inboxTasks.filter { t in
                !overdueTasks.contains(where: { $0.id == t.id }) &&
                !targetTasks.contains(where: { $0.id == t.id })
            })
        }

        let taskCards: [TaskCard]? = allRelevant.isEmpty ? nil : Array(allRelevant.prefix(15).map { task in
            TaskCard(
                id: task.id, title: task.title, project: task.project?.title,
                area: task.area?.title, whenDate: task.whenDate,
                deadline: task.deadline, isCompleted: task.isCompleted
            )
        })

        // Target day's calendar events
        let targetEvents = ctx.calendarEvents.filter { cal.isDate($0.startDate, inSameDayAs: targetDate) }
        let eventCards: [EventCard]? = targetEvents.isEmpty ? nil : targetEvents.map { event in
            EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
        }

        return AgentResponse(
            message: message,
            affectedTaskIDs: allRelevant.map(\.id),
            taskCards: taskCards,
            eventCards: eventCards,
            isPlanDay: true
        )
    }

    // MARK: - Action: Propose Reschedule

    private func buildProposal(_ response: GeminiActionResponse, message: String, ctx: AgentContext) -> AgentResponse {
        let title = response.eventTitle ?? response.title ?? "Event"
        let originalStart = response.eventStart.flatMap { parseDatetime($0) }
        let originalEnd = response.eventEnd.flatMap { parseDatetime($0) }
        let location = response.eventLocation

        let options: [ScheduleOption] = (response.suggestions ?? []).compactMap { suggestion in
            guard let start = parseDatetime(suggestion.start),
                  let end = parseDatetime(suggestion.end) else { return nil }
            return ScheduleOption(
                label: suggestion.label,
                startDate: start,
                endDate: end,
                reason: suggestion.reason,
                location: location
            )
        }

        let proposal = ScheduleProposal(
            eventTitle: title,
            originalStart: originalStart,
            originalEnd: originalEnd,
            conflictDescription: message,
            suggestions: options
        )

        return AgentResponse(message: message, proposal: proposal)
    }

    // MARK: - Card Matching for Query/Chat Responses

    private func matchCalendarEvents(message: String, calendarEvents: [CalendarEvent]) -> [EventCard] {
        let messageLower = message.lowercased()
        return calendarEvents.filter { event in
            messageLower.contains(event.title.lowercased())
        }.map { event in
            EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
        }
    }

    private func matchTaskCards(message: String, tasks: [TaskItem]) -> [TaskCard] {
        let messageLower = message.lowercased()
        return tasks.filter { task in
            messageLower.contains(task.title.lowercased())
        }.prefix(10).map { task in
            TaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
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

        // ISO 8601 with timezone
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmed) { return date }

        // ISO 8601 without timezone (YYYY-MM-DDTHH:mm:ss)
        let localIso = DateFormatter()
        localIso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localIso.timeZone = .current
        if let date = localIso.date(from: trimmed) { return date }

        // YYYY-MM-DD HH:mm
        let spaceFmt = DateFormatter()
        spaceFmt.dateFormat = "yyyy-MM-dd HH:mm"
        spaceFmt.timeZone = .current
        if let date = spaceFmt.date(from: trimmed) { return date }

        // Time-only formats (assume today): "7:00 PM", "3:30pm", "19:00"
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

        // "tomorrow at 3pm", "today at 7:00 PM", "tomorrow night" — extract date prefix + time
        let prefixPattern = #"^(today|tomorrow|tonight)\s*(?:(?:at|night|evening)\s*)?(.*)$"#
        if let regex = try? NSRegularExpression(pattern: prefixPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let dayRange = Range(match.range(at: 1), in: trimmed) {
            let dayStr = String(trimmed[dayRange]).lowercased()
            let baseDate = parseDate(dayStr == "tonight" ? "today" : dayStr) ?? Calendar.current.startOfDay(for: .now)

            let timeStr: String
            if let timeRange = Range(match.range(at: 2), in: trimmed) {
                timeStr = String(trimmed[timeRange]).trimmingCharacters(in: .whitespaces)
            } else {
                timeStr = ""
            }

            if !timeStr.isEmpty, let timeOnly = parseDatetime(timeStr) {
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: timeOnly)
                return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: baseDate)
            }

            // "tonight" / "tomorrow night" with no explicit time → default to 7:00 PM
            if dayStr == "tonight" || trimmed.lowercased().contains("night") || trimmed.lowercased().contains("evening") {
                return Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: baseDate)
            }
        }

        // "<time> tomorrow/today" — e.g. "7pm tomorrow", "3:00 PM today"
        let suffixPattern = #"^(.+?)\s+(today|tomorrow|tonight)$"#
        if let regex = try? NSRegularExpression(pattern: suffixPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let timeRange = Range(match.range(at: 1), in: trimmed),
           let dayRange = Range(match.range(at: 2), in: trimmed) {
            let dayStr = String(trimmed[dayRange]).lowercased()
            let timeStr = String(trimmed[timeRange])
            let baseDate = parseDate(dayStr == "tonight" ? "today" : dayStr) ?? Calendar.current.startOfDay(for: .now)
            if let timeOnly = parseDatetime(timeStr) {
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: timeOnly)
                return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: baseDate)
            }
        }

        // Fall back to date-only parsing
        return parseDate(trimmed)
    }

    /// Extracts a datetime from natural language like "add a dinner event tomorrow at 7 pm"
    /// by finding a day reference and a time reference within the string.
    private func extractDatetimeFromNaturalLanguage(_ text: String) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Find the day
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

        // Default to today if no day found
        if baseDate == nil { baseDate = today }

        // Find the time — look for patterns like "7 pm", "7:00 PM", "3pm", "19:00"
        let timePattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text) {
            var hour = Int(text[hourRange]) ?? 0
            let minute: Int
            if let minRange = Range(match.range(at: 2), in: text) {
                minute = Int(text[minRange]) ?? 0
            } else {
                minute = 0
            }
            if let ampmRange = Range(match.range(at: 3), in: text) {
                let ampm = String(text[ampmRange]).lowercased()
                if ampm == "pm" && hour < 12 { hour += 12 }
                if ampm == "am" && hour == 12 { hour = 0 }
            }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate!)
        }

        // Try 24-hour time like "19:00"
        let time24Pattern = #"(\d{1,2}):(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: time24Pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let minRange = Range(match.range(at: 2), in: text) {
            let hour = Int(text[hourRange]) ?? 0
            let minute = Int(text[minRange]) ?? 0
            if hour >= 0 && hour <= 23 {
                return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate!)
            }
        }

        // "tonight" / "evening" with no time → 7 PM
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
            // Strip ordinal suffixes
            let cleaned = lowered
                .replacingOccurrences(of: "\\b(\\d+)(st|nd|rd|th)\\b", with: "$1", options: .regularExpression)
            for fmt in ["MMMM d", "MMM d", "MMMM d, yyyy", "MMM d, yyyy"] {
                monthDayFmt.dateFormat = fmt
                if let date = monthDayFmt.date(from: cleaned) {
                    // Assume current or next year
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

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

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
                    isInInbox: task.isInInbox,
                    locationName: task.locationName
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
            calendarEvents: ctx.calendarEvents.map { event in
                (
                    title: event.title,
                    date: dateFmt.string(from: event.startDate),
                    start: timeFmt.string(from: event.startDate),
                    end: timeFmt.string(from: event.endDate),
                    location: event.location
                )
            },
            todayDate: todayStr,
            userLocation: ctx.locationService?.locationSummary,
            weatherSummary: ctx.weatherSummary
        )
    }
}
