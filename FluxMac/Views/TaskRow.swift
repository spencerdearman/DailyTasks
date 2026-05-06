import SwiftData
import SwiftUI

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    private let eventKitSync = EventKitSyncService()
    let task: TaskItem
    let isExpanded: Bool
    let isCompleting: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    
    @State private var activeAction: TaskActionMode?
    @State private var showTagsPopover = false
    @State private var showSchedulePopover = false
    @State private var showMovePopover = false
    @State private var newSubtaskTitle = ""
    @State private var notesExpanded = false
    @State private var showDeadlineTime = false
    @State private var calendarSyncErrorMessage: String?
    
    @Query(sort: \Area.sortOrder) private var allAreas: [Area]
    @Query(sort: \Project.sortOrder) private var allProjects: [Project]
    
    private var isDone: Bool { isCompleting || task.isCompleted }
    
    private var hasCompactMeta: Bool {
        task.project != nil || task.area != nil || !task.tagList.isEmpty
        || task.effectiveDate != nil || !task.checklistItems.isEmpty
        || task.recurrenceRule != nil || task.deadline != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row: checkbox + title
            HStack(alignment: .center, spacing: 14) {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isDone ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    
                    // Collapsed inline meta
                    if !isExpanded && hasCompactMeta {
                        compactMeta
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, isExpanded ? 4 : 14)
            .opacity(isCompleting ? 0.5 : 1.0)

            // Expanded
            if isExpanded {
                expandedContent
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .alert("Calendar Sync", isPresented: calendarSyncAlertIsPresented) {
            Button("OK", role: .cancel) {
                calendarSyncErrorMessage = nil
            }
        } message: {
            Text(calendarSyncErrorMessage ?? "Something went wrong while updating Calendar.")
        }
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Divider()
            
            Button {
                Task {
                    try? await eventKitSync.upsertCalendarEvent(for: task)
                    try? modelContext.save()
                }
            } label: {
                Label(task.hasCalendarEvent ? "Update Calendar Event" : "Schedule on Calendar",
                      systemImage: task.hasCalendarEvent ? "calendar.badge.clock" : "calendar.badge.plus")
            }
            
            if task.hasCalendarEvent {
                Button(role: .destructive) {
                    Task {
                        try? await eventKitSync.removeCalendarEvent(for: task)
                        try? modelContext.save()
                    }
                } label: {
                    Label("Remove from Calendar", systemImage: "calendar.badge.minus")
                }
            }
            
            Divider()
            
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: Collapsed meta badges
    
    private var compactMeta: some View {
        HStack(spacing: 6) {
            // 1. Area / Project
            if let project = task.project {
                Badge(text: project.title, tint: project.tintHex, icon: "paperplane")
            } else if let area = task.area {
                Badge(text: area.title, tint: area.tintHex, icon: area.symbolName)
            }
            
            // 2. When date
            if let date = task.whenDate {
                DateBadge(date: date, isDeadline: false)
            }
            
            // 3. Deadline
            if let deadline = task.deadline {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text(deadlineDisplayText(deadline))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: Capsule())
            }
            
            if task.hasCalendarEvent {
                HStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text(task.suggestedCalendarStartAt.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1), in: Capsule())
            }
            
            // 4. Tags
            ForEach(task.tagList.prefix(3)) { tag in
                Badge(text: tag.title, tint: tag.tintHex)
            }
            
            // 5. Checklist
            if !task.checklistItems.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(task.checklistItems.filter(\.isCompleted).count)/\(task.checklistItems.count)")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
    }
    
    // MARK: Expanded content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tag badges — directly under title
            if !task.tagList.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(task.tagList) { tag in
                        HStack(spacing: 4) {
                            Text(tag.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: tag.tintHex))
                            Button {
                                if let assignment = task.tagAssignmentList.first(where: { $0.tag?.id == tag.id }) {
                                    modelContext.delete(assignment)
                                }
                                task.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: tag.tintHex).opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: tag.tintHex).opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 8)
            }

            // Notes
            VStack(alignment: .leading, spacing: 2) {
                TextField("Notes", text: Binding(
                    get: { task.notes },
                    set: {
                        task.notes = $0
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(notesExpanded ? nil : 5)
                
                if task.notes.count > 100 && !notesExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            notesExpanded = true
                        }
                    } label: {
                        Text("Show more")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                } else if notesExpanded && task.notes.count > 100 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            notesExpanded = false
                        }
                    } label: {
                        Text("Show less")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 56)
            
            // Subtasks section
            if !task.checklistItems.isEmpty || activeAction == .subtasks {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subtasks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 56)
                        .padding(.top, 14)
                    
                    if !task.checklistItems.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                                ChecklistRow(item: item)
                            }
                        }
                        .padding(.horizontal, 38)
                    }
                    
                    // Add subtask inline
                    if activeAction == .subtasks {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                            
                            TextField("Add subtask…", text: $newSubtaskTitle)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(.horizontal, 56)
                        .padding(.top, 2)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Bottom bar: breadcrumb on left, action buttons on right
            HStack(spacing: 0) {
                // Left: breadcrumb
                if let area = task.area {
                    HStack(spacing: 5) {
                        Image(systemName: area.symbolName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: area.tintHex))
                        Text(area.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hex: area.tintHex))
                        
                        if let project = task.project {
                            Text("›")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                            Text(project.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Date / evening badge + deadline
                HStack(spacing: 8) {
                    dateLabel
                    
                    if let deadline = task.deadline {
                        HStack(spacing: 3) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 9))
                            Text(deadlineDisplayText(deadline))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                    }
                }
                .font(.caption.weight(.medium))
                
                Spacer()
                    .frame(maxWidth: 16)
                
                // Right: action buttons
                HStack(spacing: 2) {
                    // Schedule popover (combined when + deadline)
                    Button {
                        showSchedulePopover.toggle()
                    } label: {
                        let hasScheduleData = task.whenDate != nil || task.deadline != nil || task.isEvening
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(showSchedulePopover ? .primary : (hasScheduleData ? .primary : .secondary))
                            .frame(width: 30, height: 28)
                            .background(showSchedulePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSchedulePopover, arrowEdge: .bottom) {
                        schedulePanel
                            .padding(4)
                    }

                    // Tags popover
                    Button {
                        showTagsPopover.toggle()
                    } label: {
                        Image(systemName: !task.tagList.isEmpty ? "tag.fill" : "tag")
                            .font(.system(size: 14))
                            .foregroundStyle(showTagsPopover ? .primary : (!task.tagList.isEmpty ? .primary : .secondary))
                            .frame(width: 30, height: 28)
                            .background(showTagsPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTagsPopover, arrowEdge: .bottom) {
                        TagPanel(task: task)
                            .frame(width: 220)
                            .padding(4)
                    }

                    // Subtasks toggle (inline)
                    actionButton(.subtasks, icon: "checklist", filledIcon: "checklist.checked", active: !task.checklistItems.isEmpty)

                    // Move to popover
                    Button {
                        showMovePopover.toggle()
                    } label: {
                        Image(systemName: "arrow.turn.right.up")
                            .font(.system(size: 14))
                            .foregroundStyle(showMovePopover ? .primary : .secondary)
                            .frame(width: 30, height: 28)
                            .background(showMovePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMovePopover, arrowEdge: .bottom) {
                        movePanel
                            .frame(width: 260)
                            .padding(4)
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private var dateLabel: some View {
        if let date = task.whenDate {
            if task.isEvening {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo)
                    Text("This Evening")
                        .foregroundStyle(.indigo)
                }
            } else if Calendar.current.isDateInToday(date) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text("Today")
                        .foregroundStyle(.primary)
                }
            } else {
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .foregroundStyle(.secondary)
            }
        } else if task.isEvening {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.indigo)
                Text("This Evening")
                    .foregroundStyle(.indigo)
            }
        } else if task.status == .someday {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                Text("Later")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("")
        }
    }
    
    private func deadlineDisplayText(_ deadline: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: deadline)
        let minute = cal.component(.minute, from: deadline)
        let dateStr = deadline.formatted(.dateTime.month(.abbreviated).day())
        if hour == 0 && minute == 0 {
            return dateStr
        }
        let timeStr = deadline.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
        return "\(dateStr) \(timeStr)"
    }
    
    private func actionButton(_ mode: TaskActionMode, icon: String, filledIcon: String, active: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeAction = activeAction == mode ? nil : mode
            }
        } label: {
            Image(systemName: active ? filledIcon : icon)
                .font(.system(size: 14))
                .foregroundStyle(activeAction == mode ? .primary : (active ? .primary : .secondary))
                .frame(width: 30, height: 28)
                .background(activeAction == mode ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Action panels

    private var schedulePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Quick-pick buttons (Today / Evening / Later / Clear)
                HStack(spacing: 8) {
                    let isToday = task.whenDate != nil && Calendar.current.isDateInToday(task.whenDate!) && !task.isEvening
                    let isEvening = task.isEvening
                    let isLater = task.status == .someday && task.whenDate == nil

                    scheduleQuickButton(icon: "star.fill", iconColor: .yellow, label: "Today", isSelected: isToday) {
                        task.whenDate = Calendar.current.startOfDay(for: .now)
                        task.isEvening = false
                        task.status = .active
                        task.updatedAt = .now
                        try? modelContext.save()
                    }

                    scheduleQuickButton(icon: "moon.fill", iconColor: .indigo, label: "Evening", isSelected: isEvening) {
                        task.whenDate = Calendar.current.startOfDay(for: .now)
                        task.isEvening = true
                        task.status = .active
                        task.updatedAt = .now
                        try? modelContext.save()
                    }

                    scheduleQuickButton(icon: "moon.zzz.fill", iconColor: .secondary, label: "Later", isSelected: isLater) {
                        task.status = .someday
                        task.whenDate = nil
                        task.isEvening = false
                        task.updatedAt = .now
                        try? modelContext.save()
                    }

                    if task.whenDate != nil || isLater {
                        scheduleQuickButton(icon: "xmark", iconColor: .secondary, label: "Clear") {
                            task.whenDate = nil
                            task.isEvening = false
                            task.status = .active
                            task.updatedAt = .now
                            try? modelContext.save()
                        }
                    }
                }

                CalendarGrid(
                    selectedDate: task.deadline,
                    onSelect: { date in
                        if showDeadlineTime, let existing = task.deadline {
                            let cal = Calendar.current
                            let timeComps = cal.dateComponents([.hour, .minute], from: existing)
                            var dateComps = cal.dateComponents([.year, .month, .day], from: date)
                            dateComps.hour = timeComps.hour
                            dateComps.minute = timeComps.minute
                            task.deadline = cal.date(from: dateComps) ?? date
                        } else {
                            task.deadline = date
                        }
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                )

                // Deadline controls: time toggle + clear — all in one row
                if task.deadline != nil {
                    HStack(spacing: 6) {
                        if showDeadlineTime {
                            deadlineTimeControls(deadline: task.deadline!)
                        } else {
                            Button {
                                showDeadlineTime = true
                                let cal = Calendar.current
                                let hour = cal.component(.hour, from: task.deadline!)
                                if hour == 0 {
                                    task.deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: task.deadline!)
                                }
                                task.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                    Text("Add time")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if showDeadlineTime {
                            Button {
                                showDeadlineTime = false
                                let cal = Calendar.current
                                task.deadline = cal.startOfDay(for: task.deadline!)
                                task.updatedAt = .now
                                try? modelContext.save()
                            } label: {
                                Text("Remove time")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            task.deadline = nil
                            showDeadlineTime = false
                            task.updatedAt = .now
                            try? modelContext.save()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Clear")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .padding(.top, 2)

                // Calendar section — always visible
                calendarDurationRow

                HStack(spacing: 8) {
                    Button {
                        scheduleOnCalendar()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: task.hasCalendarEvent ? "checkmark.circle.fill" : "calendar.badge.plus")
                                .font(.system(size: 11, weight: .medium))
                            Text(task.hasCalendarEvent ? "Added" : "Add to Calendar")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(task.hasCalendarEvent ? Color.green : Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if task.hasCalendarEvent || task.hasExplicitDeadlineTime {
                        Text(calendarSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if task.hasCalendarEvent {
                        Button(role: .destructive) {
                            removeFromCalendar()
                        } label: {
                            Text("Remove")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 304, alignment: .top)
        .padding(14)
        .onAppear {
            syncCalendarPanelState()
            if let deadline = task.deadline {
                let cal = Calendar.current
                let hour = cal.component(.hour, from: deadline)
                let minute = cal.component(.minute, from: deadline)
                showDeadlineTime = hour != 0 || minute != 0
            }
        }
    }

    private func scheduleQuickButton(icon: String, iconColor: Color, label: String, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func deadlineTimeControls(deadline: Date) -> some View {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: deadline)
        let minute = cal.component(.minute, from: deadline)
        let is12Hour = hour % 12 == 0 ? 12 : hour % 12

        return HStack(spacing: 0) {
            Menu {
                ForEach(1...12, id: \.self) { h in
                    Button("\(h)") {
                        let newHour = hour >= 12 ? (h % 12) + 12 : h % 12
                        task.deadline = cal.date(bySettingHour: newHour, minute: minute, second: 0, of: deadline)
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
            } label: {
                Text("\(is12Hour)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Text(":")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Button(String(format: "%02d", m)) {
                        task.deadline = cal.date(bySettingHour: hour, minute: m, second: 0, of: deadline)
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
            } label: {
                Text(String(format: "%02d", minute))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                Button("AM") {
                    if hour >= 12 {
                        task.deadline = cal.date(bySettingHour: hour - 12, minute: minute, second: 0, of: deadline)
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
                Button("PM") {
                    if hour < 12 {
                        task.deadline = cal.date(bySettingHour: hour + 12, minute: minute, second: 0, of: deadline)
                        task.updatedAt = .now
                        try? modelContext.save()
                    }
                }
            } label: {
                Text(hour < 12 ? "AM" : "PM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var movePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.right.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Move task")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            
            Button {
                moveToInbox()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.isInInbox ? "checkmark.circle.fill" : "tray")
                        .font(.system(size: 12))
                        .foregroundStyle(task.isInInbox ? .green : .secondary)
                    Text("Inbox")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(task.isInInbox ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            
            if !allAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Areas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(allAreas) { area in
                                areaMoveRow(area)
                                
                                let projectsInArea = allProjects.filter { $0.area?.id == area.id }
                                if !projectsInArea.isEmpty {
                                    ForEach(projectsInArea) { project in
                                        projectMoveRow(project, in: area)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
        .frame(minWidth: 240)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func areaMoveRow(_ area: Area) -> some View {
        let isSelected = task.area?.id == area.id && task.project == nil
        
        return Button {
            moveToArea(area)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: area.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: area.tintHex))
                    .frame(width: 14)
                Text(area.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func projectMoveRow(_ project: Project, in area: Area) -> some View {
        let isSelected = task.project?.id == project.id
        
        return Button {
            moveToProject(project, in: area)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                Text(project.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.leading, 16)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func moveToInbox() {
        task.area = nil
        task.project = nil
        task.heading = nil
        task.isInInbox = true
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }
    
    private func moveToArea(_ area: Area) {
        task.area = area
        task.project = nil
        task.heading = nil
        task.isInInbox = false
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }
    
    private func moveToProject(_ project: Project, in area: Area) {
        task.area = area
        task.project = project
        task.heading = nil
        task.isInInbox = false
        task.updatedAt = .now
        try? modelContext.save()
        showMovePopover = false
    }
    
    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        let item = ChecklistItem(
            title: title,
            sortOrder: Double(task.checklistItems.count),
            task: task
        )
        modelContext.insert(item)
        if task.checklist == nil {
            task.checklist = []
        }
        task.checklist?.append(item)
        try? modelContext.save()
        newSubtaskTitle = ""
    }
    
    private var calendarSyncAlertIsPresented: Binding<Bool> {
        Binding(
            get: { calendarSyncErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    calendarSyncErrorMessage = nil
                }
            }
        )
    }
    
    private var calendarDurationBinding: Binding<Int> {
        Binding(
            get: { max(task.calendarDurationMinutes, 15) },
            set: { newValue in
                task.calendarDurationMinutes = max(newValue, 15)
                task.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private var calendarDurationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Duration")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach([15, 30, 45, 60, 90, 120, 180, 240, 480], id: \.self) { duration in
                    Button("\(duration) min") {
                        calendarDurationBinding.wrappedValue = duration
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(calendarDurationBinding.wrappedValue) min")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var calendarSchedulingStartAt: Date {
        if task.hasExplicitDeadlineTime, let deadline = task.deadline {
            return deadline
        }
        return task.calendarStartAt ?? task.suggestedCalendarStartAt
    }

    private var calendarSummaryText: String {
        let startAt = calendarSchedulingStartAt
        return "\(startAt.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute())) · \(calendarDurationBinding.wrappedValue) min"
    }
    
    private func syncCalendarPanelState() {
        task.calendarDurationMinutes = max(task.calendarDurationMinutes, 15)
    }
    
    private func scheduleOnCalendar() {
        Task {
            do {
                ensureCalendarStartAtForScheduling()
                try await eventKitSync.upsertCalendarEvent(for: task)
                try? modelContext.save()
            } catch {
                calendarSyncErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func removeFromCalendar() {
        Task {
            do {
                try await eventKitSync.removeCalendarEvent(for: task)
                try? modelContext.save()
            } catch {
                calendarSyncErrorMessage = error.localizedDescription
            }
        }
    }

    private func ensureCalendarStartAtForScheduling() {
        let startAt = calendarSchedulingStartAt
        task.calendarStartAt = startAt
        task.whenDate = Calendar.current.startOfDay(for: startAt)
        task.calendarDurationMinutes = max(task.calendarDurationMinutes, 15)
        task.updatedAt = .now
    }
}
