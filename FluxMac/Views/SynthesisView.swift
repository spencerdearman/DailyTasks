//
//  SynthesisView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - SynthesisView

/// Displays the AI-generated daily briefing with greeting, conflicts, and a suggested plan.
struct SynthesisView: View {

    // MARK: Properties

    let synthesis: DailySynthesis
    let overdueTasks: [TaskItem]
    let weatherSummary: String?
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showOverdueTasks = false

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)
                .opacity(0.4)

            contentScroll

            footerButton
        }
        .frame(width: 480)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 12)
        .scaleEffect(showContent ? 1 : 0.97)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showContent = true
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(periodGreeting)
                        .font(.system(size: 22, weight: .semibold))
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Weather row — integrated below greeting
            if let weather = weatherSummary {
                HStack(spacing: 6) {
                    Image(systemName: weatherIcon(for: weather))
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)

                    Text(weather)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    // MARK: Content

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Greeting
                if !synthesis.greeting.isEmpty {
                    greetingSection
                }

                // Conflicts
                if !synthesis.conflicts.isEmpty {
                    conflictsSection
                }

                // Your Day — timeline
                if !synthesis.suggestedPlan.isEmpty {
                    suggestedPlanTimeline
                }

                // Overdue tasks
                if !overdueTasks.isEmpty {
                    overdueSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxHeight: 420)
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 4)
            }
        )
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        Text(markdownString(synthesis.greeting))
            .font(.system(size: 13))
            .foregroundStyle(.primary.opacity(0.75))
            .lineSpacing(3)
    }

    // MARK: - Conflicts

    private var conflictsSection: some View {
        synthesisSection("Heads Up", icon: "exclamationmark.triangle.fill", iconColor: .orange) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(synthesis.conflicts.enumerated()), id: \.offset) { _, conflict in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)

                        Text(markdownString(conflict))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.75))
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    // MARK: - Suggested Plan Timeline

    private var suggestedPlanTimeline: some View {
        let blocks = parseTimeBlocks(synthesis.suggestedPlan)

        return synthesisSection("Your Day", icon: "calendar.badge.clock", iconColor: .blue) {
            if blocks.isEmpty {
                // Fallback: render as markdown if parsing fails
                Text(markdownString(synthesis.suggestedPlan))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineSpacing(3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        let times = splitTimeRange(block.timeRange)

                        HStack(alignment: .top, spacing: 0) {
                            // Stacked time
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(times.start)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.55))
                                if let end = times.end {
                                    Text(end)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: 64, alignment: .trailing)

                            // Accent bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor(for: block.blockType))
                                .frame(width: 3)
                                .padding(.leading, 8)
                                .padding(.trailing, 10)
                                .padding(.vertical, 2)

                            // Description
                            Text(markdownString(block.description))
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.8))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)

                        if index < blocks.count - 1 {
                            Divider()
                                .padding(.leading, 82)
                                .opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overdue Section

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tappable to expand
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showOverdueTasks.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))

                    Text("Overdue")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(overdueTasks.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.1), in: Capsule())

                    Spacer()

                    Image(systemName: showOverdueTasks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable task list
            if showOverdueTasks {
                VStack(spacing: 0) {
                    ForEach(overdueTasks.prefix(8)) { task in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color.primary.opacity(0.2))

                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            if let date = task.effectiveDate {
                                Text(shortDate(date))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(Color.red.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Footer

    private var footerButton: some View {
        Button {
            onDismiss()
        } label: {
            Text(periodDismissLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 8)
    }

    // MARK: - Period-Aware Text

    private var periodGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 12 { return "Good Morning, Spencer" }
        if hour >= 12 && hour < 17 { return "Good Afternoon, Spencer" }
        return "Good Evening, Spencer"
    }

    private var periodDismissLabel: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 12 { return "Start Your Day" }
        if hour >= 12 && hour < 17 { return "Back to Work" }
        return "Wind Down"
    }

    // MARK: - Parsing (reused from DailyPlanCard)

    private func parseTimeBlocks(_ text: String) -> [TimeBlock] {
        // Unescape literal \n from Gemini responses
        let cleaned = text.replacingOccurrences(of: "\\n", with: "\n")

        // Try line-by-line first
        var blocks: [TimeBlock] = []
        let lines = cleaned.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, looksLikeTimeBlock(trimmed) else { continue }
            if let block = extractBlock(from: trimmed) {
                blocks.append(block)
            }
        }
        if blocks.count > 1 { return blocks }

        // Inline fallback
        let timePattern = #"\*{0,2}(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]+\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\*{0,2}\s*[—–:]\s*"#
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: []) else { return blocks }
        let nsText = cleaned as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return blocks }

        blocks = []
        for (i, match) in matches.enumerated() {
            let timeRange = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "*")))
            let descStart = match.range.location + match.range.length
            let descEnd = i + 1 < matches.count ? matches[i + 1].range.location : nsText.length
            guard descStart < descEnd else { continue }
            let desc = nsText.substring(with: NSRange(location: descStart, length: descEnd - descStart))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ".")))
            guard !desc.isEmpty else { continue }
            blocks.append(TimeBlock(timeRange: timeRange, description: desc, blockType: classifyBlock(desc)))
        }
        return blocks
    }

    private func extractBlock(from line: String) -> TimeBlock? {
        let patterns = [
            #"^\*{1,2}(.+?)\*{1,2}\s*[—–\-:]\s*(.+)$"#,
            #"^(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\s*[—–\-]\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?)\s*[—–\-:]\s*(.+)$"#,
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
        // Fallback dash split
        for dash in ["—", "–", " - ", ": "] {
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

    private func looksLikeTimeBlock(_ line: String) -> Bool {
        line.replacingOccurrences(of: "*", with: "")
            .range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }

    private func classifyBlock(_ description: String) -> TimeBlock.BlockType {
        let lower = description.lowercased()
        if lower.contains("flex") || lower.contains("buffer") || lower.contains("wrap up") { return .flex }
        if lower.contains("lunch") || lower.contains("errand") || lower.contains("break") ||
           lower.contains("pick up") || lower.contains("gym") || lower.contains("run ") ||
           lower.contains("personal") { return .errand }
        return .focus
    }

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

    private func accentColor(for type: TimeBlock.BlockType) -> Color {
        switch type {
        case .calendar: return .blue
        case .focus:    return .orange
        case .errand:   return .green
        case .flex:     return .purple
        }
    }

    // MARK: - Helpers

    private func synthesisSection<Content: View>(
        _ title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: synthesis.date)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func weatherIcon(for summary: String) -> String {
        let lower = summary.lowercased()
        if lower.contains("rain") || lower.contains("shower") { return "cloud.rain.fill" }
        if lower.contains("cloud") || lower.contains("overcast") { return "cloud.fill" }
        if lower.contains("snow") { return "cloud.snow.fill" }
        if lower.contains("storm") || lower.contains("thunder") { return "cloud.bolt.fill" }
        if lower.contains("wind") { return "wind" }
        if lower.contains("fog") { return "cloud.fog.fill" }
        return "sun.max.fill"
    }

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}
