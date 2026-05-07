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
        case calendar   // An existing calendar event
        case focus      // Deep work / task block
        case errand     // Errands, breaks, personal
        case flex       // Flex / buffer time
    }
}

// MARK: - DailyPlanCard

/// A structured timeline card for plan_day responses in the agent overlay.
struct DailyPlanCard: View {

    let message: String
    let taskCards: [TaskCard]?
    let eventCards: [EventCard]?

    private var timeBlocks: [TimeBlock] {
        parseTimeBlocks(from: message)
    }

    private var headerText: String {
        // Extract the intro line before the first time block
        let lines = message.components(separatedBy: "\n")
        var intro: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if looksLikeTimeBlock(trimmed) { break }
            intro.append(trimmed)
        }
        return intro.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Intro text (if any)
            if !headerText.isEmpty {
                Text(markdownString(headerText))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.65))
                    .lineSpacing(2)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
            }

            // Timeline
            if !timeBlocks.isEmpty {
                timeline
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // Task cards (compact)
            if let cards = taskCards, !cards.isEmpty {
                taskSection(cards)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.day.timeline.leading")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Daily Plan")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            Text(dateLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(timeBlocks.enumerated()), id: \.element.id) { index, block in
                HStack(alignment: .top, spacing: 10) {
                    // Time label
                    Text(block.timeRange)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 105, alignment: .trailing)
                        .padding(.top, 2)

                    // Timeline indicator
                    VStack(spacing: 0) {
                        Circle()
                            .fill(accentColor(for: block.blockType))
                            .frame(width: 8, height: 8)
                            .padding(.top, 3)

                        if index < timeBlocks.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 1.5)
                                .frame(minHeight: 24)
                        }
                    }
                    .frame(width: 10)

                    // Description
                    VStack(alignment: .leading, spacing: 3) {
                        Text(markdownString(block.description))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Show matching event card inline if this is a calendar block
                        if block.blockType == .calendar, let events = eventCards {
                            if let matchingEvent = findMatchingEvent(block: block, events: events) {
                                inlineEventBadge(matchingEvent)
                            }
                        }
                    }
                    .padding(.bottom, index < timeBlocks.count - 1 ? 10 : 4)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Inline Event Badge

    private func inlineEventBadge(_ event: EventCard) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.blue.opacity(0.5))
                .frame(width: 2.5, height: 14)

            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.blue.opacity(0.8))

            if let loc = event.location, !loc.isEmpty {
                Text("@ \(loc)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Task Section

    private func taskSection(_ cards: [TaskCard]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("Tasks")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ForEach(cards) { task in
                HStack(spacing: 8) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(task.isCompleted ? .green : Color.secondary.opacity(0.3))

                    Text(task.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(task.isCompleted ? .secondary : Color.primary.opacity(0.8))
                        .lineLimit(1)

                    Spacer()

                    if let project = task.project {
                        Text(project)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    if let date = task.whenDate ?? task.deadline {
                        Text(shortDate(date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isOverdue(date) ? Color.red.opacity(0.8) : Color.gray)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
            }
        }
        .padding(.bottom, 6)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Parsing

    private func parseTimeBlocks(from text: String) -> [TimeBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [TimeBlock] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Match patterns like:
            // *7:00 – 8:00 AM* — description
            // 7:00 – 8:00 AM — description
            // *7:00 AM – 8:00 AM* — description
            // **7:00 – 8:00 AM** — description
            let patterns = [
                // *time* — desc  or  *time* - desc
                #"^\*{1,2}(.+?)\*{1,2}\s*[—–\-]\s*(.+)$"#,
                // time — desc (no asterisks)
                #"^(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\s*[—–\-]\s*(.+)$"#,
            ]

            var matched = false
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
                   match.numberOfRanges >= 3 {
                    let timeRange = String(trimmed[Range(match.range(at: 1), in: trimmed)!]).trimmingCharacters(in: .whitespaces)
                    let desc = String(trimmed[Range(match.range(at: 2), in: trimmed)!]).trimmingCharacters(in: .whitespaces)
                    let blockType = classifyBlock(desc)
                    blocks.append(TimeBlock(timeRange: timeRange, description: desc, blockType: blockType))
                    matched = true
                    break
                }
            }

            if !matched && looksLikeTimeBlock(trimmed) {
                // Fallback: try splitting on em-dash
                let dashVariants = ["—", "–", " - "]
                for dash in dashVariants {
                    if let range = trimmed.range(of: dash) {
                        let before = String(trimmed[trimmed.startIndex..<range.lowerBound])
                            .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
                        let after = String(trimmed[range.upperBound...])
                            .trimmingCharacters(in: .whitespaces)
                        if !before.isEmpty && !after.isEmpty {
                            blocks.append(TimeBlock(timeRange: before, description: after, blockType: classifyBlock(after)))
                            break
                        }
                    }
                }
            }
        }

        return blocks
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
           lower.contains("pick up") || lower.contains("gym") || lower.contains("run") {
            return .errand
        }
        // Check if it references a known calendar event
        if let events = eventCards {
            for event in events {
                if lower.contains(event.title.lowercased()) {
                    return .calendar
                }
            }
        }
        return .focus
    }

    private func findMatchingEvent(block: TimeBlock, events: [EventCard]) -> EventCard? {
        let lower = block.description.lowercased()
        return events.first { lower.contains($0.title.lowercased()) }
    }

    // MARK: - Helpers

    private func accentColor(for type: TimeBlock.BlockType) -> Color {
        switch type {
        case .calendar: return .blue
        case .focus:    return .orange
        case .errand:   return .green
        case .flex:     return .purple.opacity(0.6)
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
