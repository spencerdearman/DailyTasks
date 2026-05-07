//
//  DailyPlanCard.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - Time Block Model

struct TimeBlock: Identifiable {
    let id = UUID()
    let timeRange: String
    let description: String
    let blockType: BlockType

    enum BlockType {
        case calendar
        case focus
        case errand
        case flex
    }
}

// MARK: - DailyPlanCard

struct DailyPlanCard: View {

    let message: String
    let taskCards: [TaskCard]?
    let eventCards: [EventCard]?
    var weatherSummary: String? = nil

    private var parsed: ParsedPlan {
        parsePlan(from: message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)

                Text("Your Day")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(dateLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)

                    if let weather = weatherSummary {
                        Text(weather)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 16)
                .opacity(0.4)

            // Summary line
            if !parsed.intro.isEmpty {
                Text(markdownString(parsed.intro))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }

            // Schedule blocks
            if !parsed.blocks.isEmpty {
                scheduleList
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            } else {
                // Fallback: render the full message as styled markdown
                Text(markdownString(parsed.intro.isEmpty ? message : message.replacingOccurrences(of: parsed.intro, with: "").trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            // Tasks
            if let cards = taskCards, !cards.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .opacity(0.3)

                taskList(cards)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        VStack(spacing: 0) {
            ForEach(parsed.blocks) { block in
                let times = splitTimeRange(block.timeRange)
                HStack(alignment: .top, spacing: 0) {
                    // Time column — stacked start/end
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(times.start)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.6))
                        if let end = times.end {
                            Text(end)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 72, alignment: .trailing)

                    // Accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor(for: block.blockType))
                        .frame(width: 3)
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .padding(.vertical, 2)

                    // Content
                    VStack(alignment: .leading, spacing: 3) {
                        Text(markdownString(block.description))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Inline event badge
                        if block.blockType == .calendar, let events = eventCards,
                           let event = events.first(where: { block.description.localizedCaseInsensitiveContains($0.title) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8))
                                Text(event.title)
                                    .font(.system(size: 10, weight: .medium))
                                if let loc = event.location, !loc.isEmpty {
                                    Text(loc)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.blue.opacity(0.7))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                    .padding(.trailing, 16)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            }
        }
    }

    /// Splits "9:00 AM – 10:30 AM" into (start: "9:00 AM", end: "10:30 AM")
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

    // MARK: - Task List

    private func taskList(_ cards: [TaskCard]) -> some View {
        VStack(spacing: 0) {
            ForEach(cards) { task in
                HStack(spacing: 8) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundColor(task.isCompleted ? .green : Color.primary.opacity(0.2))

                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
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
                            .foregroundColor(isOverdue(date) ? .red : .secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - Parsing

    private struct ParsedPlan {
        let intro: String
        let blocks: [TimeBlock]
    }

    private func parsePlan(from text: String) -> ParsedPlan {
        // Unescape literal \n from Gemini responses
        let cleaned = text.replacingOccurrences(of: "\\n", with: "\n")

        // First try line-by-line parsing
        var blocks = parseLineByLine(cleaned)

        // If that yields <= 1 block, the model likely put everything in one paragraph.
        // Try splitting on inline time patterns.
        if blocks.count <= 1 {
            blocks = parseInline(cleaned)
        }

        // Extract intro: everything before the first time reference
        let intro = extractIntro(from: cleaned)

        return ParsedPlan(intro: intro, blocks: blocks)
    }

    private func parseLineByLine(_ text: String) -> [TimeBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [TimeBlock] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, looksLikeTimeBlock(trimmed) else { continue }
            if let block = extractBlock(from: trimmed) {
                blocks.append(block)
            }
        }
        return blocks
    }

    private func parseInline(_ text: String) -> [TimeBlock] {
        // Split on time patterns like "*9:00 AM – 12:00 PM*" or "9:00 AM – 12:00 PM"
        // The regex finds time ranges and splits the text around them
        let timePattern = #"\*{0,2}(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]+\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\*{0,2}\s*[—–\-]\s*"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [] }

        var blocks: [TimeBlock] = []

        for (i, match) in matches.enumerated() {
            let timeRange = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))

            let descStart = match.range.location + match.range.length
            let descEnd: Int
            if i + 1 < matches.count {
                // Find the start of the next time pattern, but back up to trim trailing punctuation/space
                descEnd = matches[i + 1].range.location
            } else {
                descEnd = nsText.length
            }

            guard descStart < descEnd else { continue }
            let desc = nsText.substring(with: NSRange(location: descStart, length: descEnd - descStart))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ".")))

            guard !desc.isEmpty else { continue }
            blocks.append(TimeBlock(timeRange: timeRange, description: desc, blockType: classifyBlock(desc)))
        }

        return blocks
    }

    private func extractBlock(from line: String) -> TimeBlock? {
        // Try: *time* — desc
        let patterns = [
            #"^\*{1,2}(.+?)\*{1,2}\s*[—–\-]\s*(.+)$"#,
            #"^(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\s*[—–\-]\s*(.+)$"#,
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

        // Fallback: split on first em-dash after a time-like string
        for dash in ["—", "–", " - "] {
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

    private func extractIntro(from text: String) -> String {
        // Everything before the first time-like pattern
        let stripped = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
        guard let match = stripped.range(of: #"\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?"#, options: .regularExpression) else {
            return ""
        }
        let intro = String(stripped[stripped.startIndex..<match.lowerBound])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "!.")))
        // Only return if it's a real intro (not just whitespace or very short)
        return intro.count > 10 ? intro : ""
    }

    private func looksLikeTimeBlock(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: "*", with: "")
        return stripped.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }

    private func classifyBlock(_ description: String) -> TimeBlock.BlockType {
        let lower = description.lowercased()
        if lower.contains("flex") || lower.contains("buffer") || lower.contains("wrap up") {
            return .flex
        }
        if lower.contains("lunch") || lower.contains("errand") || lower.contains("break") ||
           lower.contains("pick up") || lower.contains("gym") || lower.contains("run ") ||
           lower.contains("personal") {
            return .errand
        }
        if let events = eventCards {
            for event in events {
                if lower.contains(event.title.lowercased()) {
                    return .calendar
                }
            }
        }
        return .focus
    }

    // MARK: - Styling

    private func accentColor(for type: TimeBlock.BlockType) -> Color {
        switch type {
        case .calendar: return .blue
        case .focus:    return .orange
        case .errand:   return .green
        case .flex:     return .purple
        }
    }

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: Date())
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

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }
}
