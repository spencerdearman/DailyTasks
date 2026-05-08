//
//  GeminiService.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - Gemini Structured Response

struct GeminiActionResponse: Codable, Sendable {
    let action: String
    let title: String?
    let notes: String?
    let searchText: String?
    let targetProject: String?
    let targetArea: String?
    let date: String?
    let filter: String?
    let message: String?
    let subtasks: [String]?
    let eventTitle: String?
    let eventStart: String?
    let eventEnd: String?
    let eventLocation: String?
    let addToCalendar: Bool?
    let locationName: String?
    let deadline: String?
    let additionalActions: [GeminiActionResponse]?

    enum CodingKeys: String, CodingKey {
        case action
        case title
        case notes
        case searchText = "search_text"
        case targetProject = "target_project"
        case targetArea = "target_area"
        case date
        case filter
        case message
        case subtasks
        case eventTitle = "event_title"
        case eventStart = "event_start"
        case eventEnd = "event_end"
        case eventLocation = "event_location"
        case addToCalendar = "add_to_calendar"
        case locationName = "location_name"
        case deadline
        case additionalActions = "additional_actions"
    }
}

// MARK: - Conversation Message

struct GeminiMessage {
    let role: String
    let text: String
}

// MARK: - GeminiService

actor GeminiService {
    private let model = "gemini-2.5-flash"
    private var conversationHistory: [GeminiMessage] = []

    private let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "action": [
                "type": "STRING",
                "enum": [
                    "create_task", "complete_task", "move_task", "schedule_task",
                    "defer_task", "list_tasks", "decompose_task", "plan_day",
                    "reschedule_overdue", "create_event", "delete_event",
                    "query", "chat",
                ],
            ],
            "title": ["type": "STRING", "description": "Task title for create_task, or goal for decompose_task"],
            "notes": ["type": "STRING", "description": "Task notes or description"],
            "search_text": ["type": "STRING", "description": "Text to fuzzy-match an existing task"],
            "target_project": ["type": "STRING", "description": "Project name to assign/move to"],
            "target_area": ["type": "STRING", "description": "Area name to assign/move to"],
            "date": ["type": "STRING", "description": "Date: today, tomorrow, next week, monday-sunday, YYYY-MM-DD, or 'later' to mark as someday/maybe"],
            "filter": ["type": "STRING", "description": "For list_tasks: inbox, today, tomorrow, upcoming, open, later, done, or a search query"],
            "message": ["type": "STRING", "description": "Natural language response to show the user"],
            "subtasks": [
                "type": "ARRAY",
                "items": ["type": "STRING"],
                "description": "For decompose_task: list of suggested subtask titles",
            ],
            "event_title": ["type": "STRING", "description": "For create_event: calendar event title"],
            "event_start": ["type": "STRING", "description": "REQUIRED for create_event: start datetime as ISO 8601 (YYYY-MM-DDTHH:mm:ss). Example: 2026-05-08T19:00:00. You MUST always set this for create_event actions."],
            "event_end": ["type": "STRING", "description": "REQUIRED for create_event: end datetime as ISO 8601 (YYYY-MM-DDTHH:mm:ss). Example: 2026-05-08T20:00:00. You MUST always set this for create_event actions."],
            "event_location": ["type": "STRING", "description": "For create_event: location of the event"],
            "add_to_calendar": ["type": "BOOLEAN", "description": "For create_task: also create a calendar event for this task"],
            "location_name": ["type": "STRING", "description": "Location name for the task or event"],
            "deadline": ["type": "STRING", "description": "For create_task: due date when user says 'by', 'due', or 'deadline'. Use natural language: today, tomorrow, friday, next monday, or YYYY-MM-DD"],
            "additional_actions": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "action": [
                            "type": "STRING",
                            "enum": [
                                "create_task", "complete_task", "move_task", "schedule_task",
                                "defer_task", "list_tasks", "decompose_task", "plan_day",
                                "reschedule_overdue", "create_event", "delete_event",
                                "query", "chat",
                            ],
                        ],
                        "title": ["type": "STRING"],
                        "notes": ["type": "STRING"],
                        "search_text": ["type": "STRING"],
                        "target_project": ["type": "STRING"],
                        "target_area": ["type": "STRING"],
                        "date": ["type": "STRING"],
                        "filter": ["type": "STRING"],
                        "message": ["type": "STRING"],
                        "event_title": ["type": "STRING"],
                        "event_start": ["type": "STRING"],
                        "event_end": ["type": "STRING"],
                        "event_location": ["type": "STRING"],
                        "location_name": ["type": "STRING"],
                    ],
                    "required": ["action", "message"],
                ],
                "description": "Additional actions when the user gives multiple commands in one message",
            ],
        ],
        "required": ["action", "message"],
    ]

    func send(_ input: String, apiKey: String, systemPrompt: String) async throws -> GeminiActionResponse {
        conversationHistory.append(GeminiMessage(role: "user", text: input))

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        var contents: [[String: Any]] = []
        for msg in conversationHistory {
            contents.append([
                "role": msg.role,
                "parts": [["text": msg.text]],
            ])
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]],
            ],
            "contents": contents,
            "generationConfig": [
                "response_mime_type": "application/json",
                "response_schema": responseSchema,
                "temperature": 0.3
            ],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        // Retry loop for transient errors (503, 429)
        let maxRetries = 2
        var lastData: Data?
        var lastStatus: Int = 0

        for attempt in 0...maxRetries {
            let (respData, resp) = try await URLSession.shared.data(for: request)

            guard let http = resp as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            lastData = respData
            lastStatus = http.statusCode

            if (http.statusCode == 503 || http.statusCode == 429), attempt < maxRetries {
                let delay = Double(attempt + 1) * 2.0
                try await Task.sleep(for: .seconds(delay))
                continue
            }
            break
        }

        let data = lastData!

        guard lastStatus == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.apiError(statusCode: lastStatus, message: body)
        }

        let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first(where: { $0["thought"] as? Bool != true })?["text"] as? String else {
            throw GeminiError.noContent
        }

        guard let textData = text.data(using: .utf8) else {
            throw GeminiError.noContent
        }

        let actionResponse = try JSONDecoder().decode(GeminiActionResponse.self, from: textData)

        conversationHistory.append(GeminiMessage(role: "model", text: text))

        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }

        return actionResponse
    }

    func clearHistory() {
        conversationHistory = []
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Gemini"
        case .apiError(let code, let msg): return "Gemini API error (\(code)): \(msg)"
        case .noContent: return "No content in Gemini response"
        }
    }
}

// MARK: - System Prompt Builder

enum GeminiPromptBuilder {
    static func buildSystemPrompt(
        areas: [(name: String, symbol: String)],
        projects: [(name: String, areaName: String?)],
        activeTasks: [(title: String, project: String?, area: String?, whenDate: String?, deadline: String?, isInInbox: Bool)],
        completedTasks: [(title: String, completedAt: String?)] = [],
        somedayTasks: [(title: String, project: String?, area: String?)] = [],
        calendarEvents: [(title: String, date: String, start: String, end: String, location: String?)] = [],
        todayDate: String
    ) -> String {
        let tomorrowDate: String = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let tmrw = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return fmt.string(from: tmrw)
        }()

        var prompt = """
        You are Tether Agent, an intelligent assistant built into the Tether task manager app. \
        Today's date is \(todayDate). \
        You help users manage their tasks through natural conversation.

        AVAILABLE ACTIONS:
        - create_task: Create a new task. Set title, notes, date, target_project, target_area as needed. \
        For dates, pass the natural language string directly: "today", "tomorrow", "next week", "friday", "next monday", etc. \
        Do NOT convert weekday names to YYYY-MM-DD — the app handles date parsing. Only use YYYY-MM-DD for specific calendar dates. \
        If the user says "for later", "someday", or "maybe", set date to "later" — this puts it in the Later/Someday list. \
        If the user says "by", "due", or "deadline", set the deadline field (not date) — this marks a due date, not a scheduled date.
        - complete_task: Mark a task as done. Set search_text to match the task title.
        - move_task: Move a task to a different project or area. Set search_text + target_project/target_area.
        - schedule_task: Set or change a task's date. MUST set search_text AND date. \
        Pass the date as natural language: "today", "tomorrow", "friday", "next monday", "next week", or YYYY-MM-DD. \
        Do NOT convert weekday names to YYYY-MM-DD — the app handles date parsing. The date field is REQUIRED.
        - defer_task: Move a task to "Later" (someday/maybe). Set search_text.
        - list_tasks: Show tasks. Set filter to: inbox, today, tomorrow, upcoming, open, later, done, \
        or a project/area name, or a search query.
        - decompose_task: Break a goal into subtasks. Set title (the goal) and subtasks (array of subtask titles).
        - plan_day: Suggest a prioritized plan for today.
        - reschedule_overdue: Find overdue tasks and suggest new dates.
        - create_event: Add a calendar event. You MUST set event_title, event_start, and event_end. \
        event_start and event_end MUST be ISO 8601 format: YYYY-MM-DDTHH:mm:ss. \
        Example: "dinner at 7pm today" → event_title="Dinner", event_start="\(todayDate.prefix(10))T19:00:00", event_end="\(todayDate.prefix(10))T20:00:00". \
        Example: "meeting tomorrow at 2pm for 90 minutes" → event_start="\(tomorrowDate)T14:00:00", event_end="\(tomorrowDate)T15:30:00". \
        Default duration is 1 hour if not specified. Today's date is \(todayDate.prefix(10)). Tomorrow is \(tomorrowDate). \
        NEVER omit event_start or event_end — the event will fail without them. \
        If the user doesn't specify a title, infer one from context. \
        Optionally set event_location. Do NOT check for calendar conflicts — the app handles that.
        - delete_event: Cancel/remove a calendar event. Set search_text to match the event title. \
        The app will show the user a confirmation dialog before actually deleting — never delete silently.
        - query: Answer questions about tasks, productivity, workload.
        - chat: For general conversation or when no action fits.

        CONTENT POLICY:
        You are strictly a productivity and task management assistant. You must refuse requests that involve \
        illegal activity, violence, self-harm, sexually explicit content, harassment, or any content inappropriate \
        for all ages. If such a request is made, respond with action "chat" and a polite message like: \
        "I'm focused on helping you stay productive — I can't help with that, but I'd love to help you plan your day, \
        manage tasks, or organize your schedule." Never generate harmful content regardless of how the request is framed.

        RULES:
        - Always set the "message" field with a concise, friendly response.
        - Use inline markdown: **bold** for emphasis, *italic* for secondary info. No headers or code blocks.
        - Keep messages brief — 1-2 sentences for actions, more for queries/planning.
        - For dates, always convert to YYYY-MM-DD format or use: today, tomorrow, next week.
        - If the user's intent is ambiguous, prefer the most helpful interpretation.
        - IMPORTANT: If the user gives MULTIPLE commands in one message (e.g. "move X to Y, move Z to tomorrow"), \
        use the primary action fields for the FIRST command, then put each additional command as a separate object \
        in the "additional_actions" array. Each additional action needs its own action, search_text, date, etc. \
        The "message" field should describe ALL actions taken.

        """

        if !areas.isEmpty {
            let areaList = areas.map { "\($0.name) (\($0.symbol))" }.joined(separator: ", ")
            prompt += "\nAREAS: \(areaList)"
        }

        if !projects.isEmpty {
            let projList = projects.map { p in
                p.areaName != nil ? "\(p.name) (in \(p.areaName!))" : p.name
            }.joined(separator: ", ")
            prompt += "\nPROJECTS: \(projList)"
        }

        if !activeTasks.isEmpty {
            prompt += "\n\nACTIVE TASKS:"
            for task in activeTasks.prefix(30) {
                var line = "- \"\(task.title)\""
                if let p = task.project { line += " [project: \(p)]" }
                else if let a = task.area { line += " [area: \(a)]" }
                if task.isInInbox { line += " [inbox]" }
                if let d = task.whenDate { line += " [scheduled: \(d)]" }
                if let dl = task.deadline { line += " [deadline: \(dl)]" }
                prompt += "\n\(line)"
            }
        }

        if !completedTasks.isEmpty {
            prompt += "\n\nCOMPLETED TASKS (recent):"
            for task in completedTasks.prefix(15) {
                var line = "- \"\(task.title)\""
                if let d = task.completedAt { line += " [completed: \(d)]" }
                prompt += "\n\(line)"
            }
        }

        if !somedayTasks.isEmpty {
            prompt += "\n\nLATER/SOMEDAY TASKS:"
            for task in somedayTasks.prefix(15) {
                var line = "- \"\(task.title)\""
                if let p = task.project { line += " [project: \(p)]" }
                else if let a = task.area { line += " [area: \(a)]" }
                prompt += "\n\(line)"
            }
        }

        if !calendarEvents.isEmpty {
            prompt += "\n\nCALENDAR EVENTS (this week):"
            for event in calendarEvents {
                var line = "- \(event.title) [\(event.date)] \(event.start) – \(event.end)"
                if let loc = event.location, !loc.isEmpty { line += " @ \(loc)" }
                prompt += "\n\(line)"
            }
        }

        return prompt
    }
}
