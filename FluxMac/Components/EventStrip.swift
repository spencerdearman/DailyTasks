//
//  EventStrip.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - EventStrip

/// A vertical timeline view displaying grouped calendar events by day.
struct EventStrip: View {
    let events: [CalendarEvent]

    // MARK: Private

    private var groupedEvents: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Calendar")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                ForEach(Array(groupedEvents.enumerated()), id: \.offset) { _, group in
                    dayCard(date: group.date, events: group.events)
                }
            }
        }
    }

    // MARK: - Day Card

    private func dayCard(date: Date, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack(spacing: 6) {
                Text(relativeDay(date))
                    .font(.system(size: 13, weight: .semibold))

                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(events.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Events
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                eventRow(event)

                if index < events.count - 1 {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 54)
                        .padding(.trailing, 16)
                }
            }

            Spacer()
                .frame(height: 6)
        }
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Event Row

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            // Time
            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            // Title + location
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 7))
                        Text(shortLocation(location))
                            .lineLimit(1)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    // MARK: - Helpers

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func shortLocation(_ location: String) -> String {
        // Show just the venue/place name, trim long addresses
        let parts = location.components(separatedBy: ",")
        if let first = parts.first {
            return String(first.prefix(40))
        }
        return String(location.prefix(40))
    }
}
