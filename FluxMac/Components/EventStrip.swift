import SwiftData
import SwiftUI

struct EventStrip: View {
    let events: [CalendarEvent]
    
    private var groupedEvents: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        
        return grouped
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Calendar")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(groupedEvents.enumerated()), id: \.offset) { groupIndex, group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 14)
                            .padding(.top, groupIndex == 0 ? 14 : 18)
                            .padding(.bottom, 6)

                        ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                            HStack(spacing: 12) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .frame(width: 56, alignment: .trailing)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.5))
                                    .frame(width: 3)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    if let location = event.location, !location.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 8))
                                            Text(location)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < group.events.count - 1 {
                                Divider()
                                    .padding(.leading, 82)
                            }
                        }
                    }
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
