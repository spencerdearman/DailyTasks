//
//  SmartEntryField.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - Parsed Entry

/// The result of parsing a natural language task entry.
struct ParsedEntry: Equatable {
    var title: String
    var notes: String = ""
    var whenDate: Date?
    var deadline: Date?
    var timeOfDay: Date?  // specific time (hour/minute) for calendar scheduling
    var areaName: String?
    var projectName: String?
    var isEvening: Bool = false
    var isUrgent: Bool = false
    var status: TaskStatus = .active
}

// MARK: - SmartEntryField

/// A natural language text field that parses input into structured task fields.
/// Shows a live preview card as the user types.
struct SmartEntryField: View {

    @Binding var rawInput: String
    @Binding var parsed: ParsedEntry?
    let areas: [Area]
    let projects: [Project]

    @AppStorage("geminiAPIKey") private var apiKey = ""
    @State private var parseTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Natural language input
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("What do you need to do?", text: $rawInput, axis: .vertical)
                    .font(.body)
                    .focused($isFocused)
                    .lineLimit(1...3)
                    .onChange(of: rawInput) { _, newValue in
                        scheduleLocalParse(newValue)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Parsed preview
            if let parsed, !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parsedPreview(parsed)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: parsed != nil)
        .onAppear { isFocused = true }
    }

    // MARK: - Preview

    private func parsedPreview(_ entry: ParsedEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thin separator
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Task preview row — matches TaskCard style
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    // Metadata chips
                    FlowLayout(spacing: 6) {
                        if let date = entry.whenDate {
                            chip(icon: "calendar", text: shortDate(date), color: .blue)
                        }
                        if let time = entry.timeOfDay {
                            chip(icon: "clock", text: timeString(time), color: .indigo)
                        }
                        if entry.isEvening {
                            chip(icon: "moon.fill", text: "Evening", color: .indigo)
                        }
                        if let deadline = entry.deadline {
                            chip(icon: "flag.fill", text: "Due \(shortDate(deadline))", color: .orange)
                        }
                        if entry.isUrgent {
                            chip(icon: "exclamationmark.triangle.fill", text: "Urgent", color: .red)
                        }
                        if let area = entry.areaName {
                            chip(icon: "square.grid.2x2", text: area, color: .teal)
                        }
                        if let project = entry.projectName {
                            chip(icon: "paperplane", text: project, color: .purple)
                        }
                        if entry.areaName == nil && entry.projectName == nil {
                            chip(icon: "tray", text: "Inbox", color: .secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func chip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    // MARK: - Local Parsing

    private func scheduleLocalParse(_ input: String) {
        parseTask?.cancel()
        parseTask = Task {
            // Small debounce
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                await MainActor.run { parsed = nil }
                return
            }

            let result = localParse(trimmed)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    parsed = result
                }
            }

            // If we have an API key, refine with categorization service
            if !apiKey.isEmpty {
                let categorizer = CategorizationService()
                let classification = await categorizer.categorize(
                    title: result.title,
                    notes: result.notes,
                    areas: areas.map { (name: $0.title, description: $0.notes) },
                    projects: projects.map { (name: $0.title, areaName: $0.area?.title) },
                    apiKey: apiKey
                )
                guard !Task.isCancelled else { return }
                if classification.area != nil || classification.project != nil {
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.15)) {
                            parsed?.areaName = classification.area ?? parsed?.areaName
                            parsed?.projectName = classification.project ?? parsed?.projectName
                        }
                    }
                }
            }
        }
    }

    /// Fast local NL parsing — extracts dates and locations from the input.
    private func localParse(_ input: String) -> ParsedEntry {
        let lower = input.lowercased()
        var title = input
        var whenDate: Date?
        var isEvening = false
        var deadline: Date?
        var areaName: String?
        var projectName: String?
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Extract "tomorrow", "today", "this evening", etc.
        if lower.contains("this evening") || lower.contains("tonight") {
            isEvening = true
            whenDate = today
            title = title.replacingOccurrences(of: "this evening", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "tonight", with: "", options: .caseInsensitive)
        } else if lower.contains("tomorrow") {
            whenDate = cal.date(byAdding: .day, value: 1, to: today)
            title = title.replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
        } else if lower.contains("today") {
            whenDate = today
            title = title.replacingOccurrences(of: "today", with: "", options: .caseInsensitive)
        } else if lower.contains("next week") {
            whenDate = cal.date(byAdding: .weekOfYear, value: 1, to: today)
            title = title.replacingOccurrences(of: "next week", with: "", options: .caseInsensitive)
        }

        // Extract weekday names
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (idx, day) in weekdays.enumerated() {
            if lower.contains(day) {
                let targetDay = idx + 1
                let currentDay = cal.component(.weekday, from: today)
                let daysAhead = (targetDay - currentDay + 7) % 7
                let offset = daysAhead == 0 ? 7 : daysAhead
                whenDate = cal.date(byAdding: .day, value: offset, to: today)
                // Remove the weekday from the title (case insensitive)
                if let range = title.range(of: day, options: .caseInsensitive) {
                    title.removeSubrange(range)
                    // Also remove "on " prefix if present
                    if let onRange = title.range(of: "on ", options: [.caseInsensitive, .backwards]) {
                        title.removeSubrange(onRange)
                    }
                }
                break
            }
        }

        // Extract time of day — "at 10 am", "at 3:30 pm", "at 14:00"
        var timeOfDay: Date?
        let timePatterns: [(pattern: String, hasMinutes: Bool)] = [
            (#"\bat\s+(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#, true),
            (#"\bat\s+(\d{1,2})\s*(am|pm|AM|PM)"#, false),
            (#"(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#, true),
            (#"(\d{1,2})\s*(am|pm|AM|PM)\b"#, false),
        ]
        for (pattern, hasMinutes) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                let hourRange = Range(match.range(at: 1), in: title)!
                var hour = Int(title[hourRange]) ?? 0
                let minute: Int
                if hasMinutes, let minRange = Range(match.range(at: 2), in: title) {
                    minute = Int(title[minRange]) ?? 0
                    let ampmRange = Range(match.range(at: 3), in: title)!
                    let ampm = String(title[ampmRange]).lowercased()
                    if ampm == "pm" && hour < 12 { hour += 12 }
                    if ampm == "am" && hour == 12 { hour = 0 }
                } else {
                    minute = 0
                    let ampmRange = Range(match.range(at: 2), in: title)!
                    let ampm = String(title[ampmRange]).lowercased()
                    if ampm == "pm" && hour < 12 { hour += 12 }
                    if ampm == "am" && hour == 12 { hour = 0 }
                }
                let baseDate = whenDate ?? today
                timeOfDay = cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
                // If no date was set yet, infer today
                if whenDate == nil { whenDate = today }
                // Remove the time from the title
                if let fullRange = Range(match.range, in: title) {
                    title.removeSubrange(fullRange)
                }
                break
            }
        }

        // Extract "morning" / "afternoon" as rough time hints
        if timeOfDay == nil {
            if lower.contains("morning") || lower.contains("in the morning") {
                let baseDate = whenDate ?? today
                timeOfDay = cal.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)
                title = title.replacingOccurrences(of: "in the morning", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "morning", with: "", options: .caseInsensitive)
            } else if lower.contains("afternoon") || lower.contains("in the afternoon") {
                let baseDate = whenDate ?? today
                timeOfDay = cal.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)
                title = title.replacingOccurrences(of: "in the afternoon", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "afternoon", with: "", options: .caseInsensitive)
            }
        }

        // Detect urgency
        let urgencySignals = ["urgent", "asap", "important", "critical", "emergency"]
        let isUrgent = urgencySignals.contains(where: { lower.contains($0) })
        // Remove urgency words from title
        for word in urgencySignals {
            title = title.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        // Clean "it is really" / "it's" / "really" type filler
        title = title.replacingOccurrences(of: #"\b(it(?:'s| is)\s+)?really\s*"#, with: "", options: [.regularExpression, .caseInsensitive])

        // Extract "by <date>" as deadline
        if let byRange = lower.range(of: #"\bby\s+(tomorrow|today|next week|\w+day)"#, options: .regularExpression) {
            let byStr = String(lower[byRange]).replacingOccurrences(of: "by ", with: "")
            if byStr == "tomorrow" {
                deadline = cal.date(byAdding: .day, value: 1, to: today)
            } else if byStr == "today" {
                deadline = today
            } else if byStr == "next week" {
                deadline = cal.date(byAdding: .weekOfYear, value: 1, to: today)
            } else if let idx = weekdays.firstIndex(of: byStr) {
                let targetDay = idx + 1
                let currentDay = cal.component(.weekday, from: today)
                let daysAhead = (targetDay - currentDay + 7) % 7
                deadline = cal.date(byAdding: .day, value: daysAhead == 0 ? 7 : daysAhead, to: today)
            }
            // Remove the "by ..." from title
            if let range = title.range(of: #"\bby\s+(tomorrow|today|next week|\w+day)"#, options: [.regularExpression, .caseInsensitive]) {
                title.removeSubrange(range)
            }
        }

        // Extract "for <project/area>" or "in <project/area>"
        for prep in ["for ", "in "] {
            if let range = lower.range(of: prep, options: .backwards) {
                let afterPrep = String(lower[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Check projects first (more specific)
                if let project = projects.first(where: { afterPrep.contains($0.title.lowercased()) }) {
                    projectName = project.title
                    areaName = project.area?.title
                    // Remove "for/in <project>" from title
                    let fullPattern = prep + project.title
                    if let r = title.range(of: fullPattern, options: .caseInsensitive) {
                        title.removeSubrange(r)
                    }
                    break
                }
                // Check areas
                if let area = areas.first(where: { afterPrep.contains($0.title.lowercased()) }) {
                    areaName = area.title
                    let fullPattern = prep + area.title
                    if let r = title.range(of: fullPattern, options: .caseInsensitive) {
                        title.removeSubrange(r)
                    }
                    break
                }
            }
        }

        // Clean up title
        title = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        // Distill: strip conversational filler to extract the actual task
        title = distillTitle(title)

        // Capitalize first letter
        if let first = title.first, first.isLowercase {
            title = first.uppercased() + title.dropFirst()
        }

        return ParsedEntry(
            title: title,
            whenDate: whenDate,
            deadline: deadline,
            timeOfDay: timeOfDay,
            areaName: areaName,
            projectName: projectName,
            isEvening: isEvening,
            isUrgent: isUrgent
        )
    }

    /// Strips conversational filler from a raw NL input to extract a concise task title.
    /// "I have a doctors appointment that I really have to get done in the morning"
    /// → "Doctors appointment"
    private func distillTitle(_ raw: String) -> String {
        var t = raw

        // Strip leading filler phrases (case insensitive)
        let leadingFillers = [
            #"^i\s+(?:need|want|have|got|should|must|gotta)\s+(?:to\s+)?"#,
            #"^i(?:'ve| have)\s+(?:got\s+)?(?:a|an|the|my)\s+"#,
            #"^(?:i\s+)?(?:need|want|have)\s+(?:a|an|the|my)\s+"#,
            #"^remind\s+me\s+(?:to\s+)?"#,
            #"^(?:add|create)\s+(?:a\s+)?(?:task\s+(?:to|for)\s+)?"#,
            #"^(?:please|pls)\s+"#,
            #"^(?:don't\s+forget\s+(?:to\s+)?)"#,
        ]
        for pattern in leadingFillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let range = Range(match.range, in: t) {
                t.removeSubrange(range)
                break // only strip the first matching filler
            }
        }

        // Strip trailing filler phrases
        let trailingFillers = [
            #"\s+(?:that\s+)?(?:i\s+)?(?:really\s+)?(?:need|have|want|got)\s+to\s+(?:get\s+)?(?:done|do|finish|complete).*$"#,
            #"\s+(?:in\s+the\s+)?(?:morning|afternoon|evening)$"#,
            #"\s+(?:as\s+soon\s+as\s+possible|asap)$"#,
            #"\s+(?:when\s+i\s+(?:can|get\s+a\s+chance))$"#,
        ]
        for pattern in trailingFillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let range = Range(match.range, in: t) {
                t.removeSubrange(range)
            }
        }

        // Strip leading articles left over after filler removal
        t = t.replacingOccurrences(of: #"^(?:a|an|the|my)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])

        // Strip stray commas, conjunctions, prepositions at edges
        t = t.replacingOccurrences(of: #"^[\s,;:\-–—]+|[\s,;:\-–—]+$"#, with: "", options: .regularExpression)

        // Collapse whitespace
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If distilling removed everything, fall back to the raw input
        if t.isEmpty { return raw.trimmingCharacters(in: .whitespacesAndNewlines) }

        return t
    }
}
