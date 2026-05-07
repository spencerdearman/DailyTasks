//
//  ScheduleProposalCard.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - ScheduleProposalCard

/// Displays a conflict resolution proposal with tappable alternative time slots.
struct ScheduleProposalCard: View {

    let proposal: ScheduleProposal
    let onSelectOption: (ScheduleOption) -> Void

    @State private var selectedOptionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("Scheduling Conflict")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 16)
                .opacity(0.4)

            // Event being scheduled
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange)
                    .frame(width: 3, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.eventTitle)
                        .font(.system(size: 13, weight: .semibold))

                    if let start = proposal.originalStart {
                        Text(formatTimeRange(start: start, end: proposal.originalEnd))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Conflict badge
                Text("Conflict")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Suggested alternatives
            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested times")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)

                ForEach(proposal.suggestions) { option in
                    suggestionRow(option)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Suggestion Row

    private func suggestionRow(_ option: ScheduleOption) -> some View {
        let isSelected = selectedOptionID == option.id

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedOptionID = option.id
            }
            // Brief delay so the user sees the selection, then execute
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSelectOption(option)
            }
        } label: {
            HStack(spacing: 0) {
                // Time
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatTime(option.startDate))
                        .font(.system(size: 12, weight: .semibold))
                    Text(formatTime(option.endDate))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 60, alignment: .trailing)

                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.green : Color.blue)
                    .frame(width: 3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                // Reason
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Text(option.reason)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Select indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.06) : Color.primary.opacity(0.03))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    // MARK: - Formatting

    private func formatTimeRange(start: Date, end: Date?) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        var result = fmt.string(from: start)
        if let end {
            result += " – " + fmt.string(from: end)
        }
        return result
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}
