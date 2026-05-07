//
//  CalendarGrid.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - CalendarGrid

/// A compact month-view calendar grid for date selection.
struct CalendarGrid: View {
    let selectedDate: Date?
    var accentColor: Color = .blue
    let onSelect: (Date) -> Void
    
    @State private var displayedMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let dayOfWeekSymbols = Calendar.current.shortWeekdaySymbols
    
    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }
    
    private var daysInGrid: [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: sel)
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Month header with navigation
            HStack {
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(dayOfWeekSymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(height: 20)
                }
            }
            
            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            onSelect(date)
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: isSelected(date) ? .semibold : .regular))
                                .foregroundStyle(isSelected(date) ? .white : (isToday(date) ? accentColor : .primary))
                                .frame(width: 32, height: 32)
                                .background {
                                    if isSelected(date) {
                                        Circle().fill(accentColor)
                                    } else if isToday(date) {
                                        Circle().fill(accentColor.opacity(0.1))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
    }
    
    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
