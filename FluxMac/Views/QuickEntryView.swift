//
//  QuickEntryView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct QuickEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \Tag.title) private var allTags: [Tag]
    
    private let eventKitSync = EventKitSyncService()
    
    let defaultSelection: SidebarSelection?
    
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var whenDate: Date?
    @State private var deadline: Date?
    @State private var isEvening = false
    @State private var calendarStartAt: Date?
    @State private var calendarDurationMinutes = 60
    @State private var showDeadlineTime = false
    @State private var showCalendarDetails = false
    @State private var shouldScheduleOnSave = false
    @State private var selectedTags: [Tag] = []
    
    @State private var showAreaPopover = false
    @State private var showProjectPopover = false
    @State private var showSchedulePopover = false
    @State private var showTagsPopover = false
    @State private var calendarSyncErrorMessage: String?
    @State private var isSchedulingOnSave = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            TextField("New task…", text: $title)
                .textFieldStyle(.plain)
                .font(.title3.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            // Notes
            TextField("Notes", text: $notes, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(.horizontal, 20)
                .frame(minHeight: 60)
            
            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            
            // Area, Project, and date/deadline badges — inline row
            FlowLayout(spacing: 8) {
                // Area popover
                Button {
                    showAreaPopover.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedAreaID != nil ? (areas.first(where: { $0.id == selectedAreaID })?.symbolName ?? "square.grid.2x2") : "square.grid.2x2")
                            .font(.system(size: 11))
                            .foregroundStyle(selectedAreaID != nil ? .primary : .secondary)
                        Text(selectedAreaID != nil ? (areas.first(where: { $0.id == selectedAreaID })?.title ?? "Area") : "Area")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedAreaID != nil ? .primary : .secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAreaPopover, arrowEdge: .bottom) {
                    areaPanel
                        .frame(width: 220)
                        .padding(4)
                }

                // Project popover
                Button {
                    showProjectPopover.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 11))
                            .foregroundStyle(selectedProjectID != nil ? .primary : .secondary)
                        Text(selectedProjectID != nil ? (filteredProjects.first(where: { $0.id == selectedProjectID })?.title ?? "Project") : "Project")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedProjectID != nil ? .primary : .secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showProjectPopover, arrowEdge: .bottom) {
                    projectPanel
                        .frame(width: 220)
                        .padding(4)
                }
                
                // Inline date badges
                if isEvening {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.indigo)
                        Text("This Evening").font(.caption.weight(.medium)).foregroundStyle(.indigo)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.08), in: Capsule())
                } else if let date = whenDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(date.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.medium))
                        Button {
                            whenDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                }
                
                if let dl = deadline {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(.orange)
                        Text(dl.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.medium)).foregroundStyle(.orange)
                        Button {
                            deadline = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.08), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Selected tags
            if !selectedTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(selectedTags) { tag in
                        HStack(spacing: 4) {
                            Text(tag.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: tag.tintHex))
                            Button {
                                selectedTags.removeAll { $0.id == tag.id }
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
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            
            Spacer(minLength: 0)
            
            // Bottom bar: popover action buttons + save
            HStack(spacing: 0) {
                // Action buttons with popovers
                HStack(spacing: 2) {
                    // Schedule popover (combined when + deadline)
                    Button {
                        showSchedulePopover.toggle()
                    } label: {
                        let hasScheduleData = whenDate != nil || deadline != nil || isEvening
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(showSchedulePopover ? .primary : (hasScheduleData ? .primary : .tertiary))
                            .frame(width: 30, height: 28)
                            .background(showSchedulePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSchedulePopover, arrowEdge: .top) {
                        schedulePanel
                            .padding(4)
                    }

                    // Tags popover
                    Button {
                        showTagsPopover.toggle()
                    } label: {
                        Image(systemName: !selectedTags.isEmpty ? "tag.fill" : "tag")
                            .font(.system(size: 14))
                            .foregroundStyle(showTagsPopover ? .primary : (!selectedTags.isEmpty ? .primary : .tertiary))
                            .frame(width: 30, height: 28)
                            .background(showTagsPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTagsPopover, arrowEdge: .top) {
                        tagsPanel
                            .frame(width: 220)
                            .padding(4)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Button {
                        saveTask()
                    } label: {
                        Text("Save")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSchedulingOnSave)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 440)
        .background(.ultraThinMaterial)
        .alert("Calendar Sync", isPresented: calendarSyncAlertIsPresented) {
            Button("OK", role: .cancel) {
                calendarSyncErrorMessage = nil
            }
        } message: {
            Text(calendarSyncErrorMessage ?? "Something went wrong while updating Calendar.")
        }
        .onAppear(perform: configureDefaults)
    }
    
    // MARK: - Schedule Panel (combined when + deadline)

    private var schedulePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    let isToday = whenDate != nil && Calendar.current.isDateInToday(whenDate!) && !isEvening

                    quickPickButton(icon: "star.fill", iconColor: .yellow, label: "Today", isSelected: isToday) {
                        whenDate = Calendar.current.startOfDay(for: .now)
                        isEvening = false
                    }

                    quickPickButton(icon: "moon.fill", iconColor: .indigo, label: "Evening", isSelected: isEvening) {
                        whenDate = Calendar.current.startOfDay(for: .now)
                        isEvening = true
                    }

                    quickPickButton(icon: "clock", iconColor: .teal, label: "Later", isSelected: {
                        guard let w = whenDate else { return false }
                        return !Calendar.current.isDateInToday(w) && !isEvening
                    }()) {
                        whenDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                        isEvening = false
                    }

                    if whenDate != nil || isEvening {
                        quickPickButton(icon: "xmark", iconColor: .secondary, label: "Clear", isSelected: false) {
                            whenDate = nil
                            isEvening = false
                        }
                    }
                }

                CalendarGrid(
                    selectedDate: deadline,
                    accentColor: .orange,
                    onSelect: { date in
                        if showDeadlineTime, let existing = deadline {
                            let cal = Calendar.current
                            let timeComps = cal.dateComponents([.hour, .minute], from: existing)
                            var dateComps = cal.dateComponents([.year, .month, .day], from: date)
                            dateComps.hour = timeComps.hour
                            dateComps.minute = timeComps.minute
                            deadline = cal.date(from: dateComps) ?? date
                        } else {
                            deadline = date
                        }
                    }
                )

                HStack(spacing: 8) {
                    Button {
                        showDeadlineTime.toggle()
                        if showDeadlineTime {
                            let cal = Calendar.current
                            if deadline == nil {
                                deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
                            } else if let deadline, !dateHasExplicitTime(deadline) {
                                self.deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: deadline)
                            }
                        } else if let deadline {
                            self.deadline = Calendar.current.startOfDay(for: deadline)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(showDeadlineTime ? "Remove time" : "Add time")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(showDeadlineTime ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    if showDeadlineTime, let deadline {
                        Spacer()
                        deadlineTimeControls(deadline: deadline)
                    }
                }

                if deadline != nil {
                    Button {
                        deadline = nil
                        showDeadlineTime = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Clear Deadline")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.top, 2)

                DisclosureGroup(isExpanded: $showCalendarDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(calendarTimingDescription)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        calendarDurationRow

                        Button {
                            if shouldScheduleOnSave {
                                shouldScheduleOnSave = false
                            } else {
                                ensureCalendarStartForScheduling()
                                shouldScheduleOnSave = true
                                showCalendarDetails = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: shouldScheduleOnSave ? "checkmark.circle.fill" : "calendar.badge.plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(shouldScheduleOnSave ? "Will Add to Calendar" : "Schedule on Calendar")
                                    .font(.body.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background((title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldScheduleOnSave ? Color.secondary : (shouldScheduleOnSave ? Color.green : Color.accentColor)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if shouldScheduleOnSave {
                            Button(role: .destructive) {
                                shouldScheduleOnSave = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.minus")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Remove from Calendar")
                                        .font(.caption.weight(.medium))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: shouldScheduleOnSave ? "calendar.badge.clock" : "calendar.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shouldScheduleOnSave ? "Calendar event on save" : "Add to calendar")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if shouldScheduleOnSave || (deadline != nil && dateHasExplicitTime(deadline!)) {
                                Text(calendarSummaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                .tint(.primary)
            }
        }
        .frame(width: 304, height: 420, alignment: .top)
        .padding(14)
    }

    // MARK: - Tags Panel (popover content)

    private var tagsPanel: some View {
        QuickEntryTagPanel(allTags: allTags, selectedTags: $selectedTags, modelContext: modelContext)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func quickPickButton(icon: String, iconColor: Color, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Area Panel (tag-style overlay)

    private var areaPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Area")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(8)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    selectedAreaID = nil
                    showAreaPopover = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("No area")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(areas) { area in
                    Button {
                        selectedAreaID = area.id
                        showAreaPopover = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: area.symbolName)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: area.tintHex))
                            Text(area.title)
                                .font(.subheadline)
                            Spacer()
                            if selectedAreaID == area.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Project Panel (tag-style overlay)

    private var projectPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(8)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    selectedProjectID = nil
                    showProjectPopover = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("No project")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(filteredProjects) { project in
                    Button {
                        selectedProjectID = project.id
                        showProjectPopover = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: project.tintHex))
                            Text(project.title)
                                .font(.subheadline)
                            Spacer()
                            if selectedProjectID == project.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var filteredProjects: [Project] {
        if let selectedAreaID {
            return projects.filter { $0.area?.id == selectedAreaID }
        }
        return projects
    }
    
    private func configureDefaults() {
        guard let defaultSelection else { return }
        switch defaultSelection {
        case .area(let id): selectedAreaID = id
        case .project(let id):
            selectedProjectID = id
            selectedAreaID = projects.first(where: { $0.id == id })?.area?.id
        case .today:
            whenDate = .now
        default: break
        }
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
            get: { max(calendarDurationMinutes, 15) },
            set: { calendarDurationMinutes = max($0, 15) }
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
        if let deadline, dateHasExplicitTime(deadline) {
            return deadline
        }
        return calendarStartAt ?? suggestedCalendarStartAt
    }

    private var calendarTimingDescription: String {
        if let deadline, dateHasExplicitTime(deadline) {
            return "Uses deadline time: \(deadline.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()))"
        }
        return "No deadline time set. Calendar will use \(calendarSchedulingStartAt.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()))."
    }

    private var calendarSummaryText: String {
        let startAt = calendarSchedulingStartAt
        return "\(startAt.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute())) · \(calendarDurationBinding.wrappedValue) min"
    }

    private var suggestedCalendarStartAt: Date {
        let calendar = Calendar.current

        if let calendarStartAt {
            return calendarStartAt
        }

        if let deadline {
            if dateHasExplicitTime(deadline) {
                return deadline
            }
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: deadline) ?? deadline
        }

        if let whenDate {
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: whenDate) ?? whenDate
        }

        let now = Date()
        return calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
    }

    private func ensureCalendarStartForScheduling() {
        let startAt = calendarSchedulingStartAt
        calendarStartAt = startAt
        whenDate = Calendar.current.startOfDay(for: startAt)
        calendarDurationMinutes = max(calendarDurationMinutes, 15)
    }

    private func dateHasExplicitTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return components.hour != 0 || components.minute != 0
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
                        self.deadline = cal.date(bySettingHour: newHour, minute: minute, second: 0, of: deadline)
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
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minuteValue in
                    Button(String(format: "%02d", minuteValue)) {
                        self.deadline = cal.date(bySettingHour: hour, minute: minuteValue, second: 0, of: deadline)
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
                        self.deadline = cal.date(bySettingHour: hour - 12, minute: minute, second: 0, of: deadline)
                    }
                }
                Button("PM") {
                    if hour < 12 {
                        self.deadline = cal.date(bySettingHour: hour + 12, minute: minute, second: 0, of: deadline)
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

    private func saveTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let selectedArea = areas.first(where: { $0.id == selectedAreaID })
        let selectedProject = projects.first(where: { $0.id == selectedProjectID })
        let routing = SemanticRouter.analyze(title: normalizedTitle, notes: normalizedNotes, areas: areas)
        
        let resolvedArea = selectedArea ?? selectedProject?.area ?? routing.matchedArea
        let resolvedWhen = whenDate ?? routing.suggestedWhen
        if shouldScheduleOnSave {
            ensureCalendarStartForScheduling()
        }
        let task = TaskItem(
            title: normalizedTitle,
            notes: normalizedNotes,
            whenDate: resolvedWhen,
            deadline: deadline,
            isInInbox: resolvedArea == nil && selectedProject == nil,
            isEvening: isEvening || routing.shouldMarkEvening,
            calendarStartAt: shouldScheduleOnSave ? calendarStartAt : nil,
            calendarDurationMinutes: calendarDurationBinding.wrappedValue,
            area: resolvedArea,
            project: selectedProject
        )
        modelContext.insert(task)
        for tag in selectedTags {
            let assignment = TaskTagAssignment(task: task, tag: tag)
            modelContext.insert(assignment)
        }
        try? modelContext.save()
        
        guard shouldScheduleOnSave else {
            dismiss()
            return
        }

        isSchedulingOnSave = true
        Task {
            do {
                try await eventKitSync.upsertCalendarEvent(for: task)
                try? modelContext.save()
                await MainActor.run {
                    isSchedulingOnSave = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSchedulingOnSave = false
                    calendarSyncErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct QuickEntryTagPanel: View {
    let allTags: [Tag]
    @Binding var selectedTags: [Tag]
    let modelContext: ModelContext
    
    @State private var searchText = ""
    
    private var filteredTags: [Tag] {
        let unassigned = allTags.filter { tag in
            !selectedTags.contains(where: { $0.id == tag.id })
        }
        if searchText.isEmpty { return unassigned }
        return unassigned.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Tags", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit { createTag() }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            if !filteredTags.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTags.prefix(6)) { tag in
                        Button {
                            selectedTags.append(tag)
                            searchText = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: tag.tintHex))
                                Text(tag.title).font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4).padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    private func createTag() {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = Tag(title: name, tintHex: Tag.nextColor(forIndex: allTags.count))
        modelContext.insert(tag)
        selectedTags.append(tag)
        try? modelContext.save()
        searchText = ""
    }
}
