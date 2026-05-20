//
//  QuickEntryView.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import MapKit
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
    
    @State private var smartInput = ""
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
    
    @State private var isLater = false
    @State private var showAreaPopover = false
    @State private var showProjectPopover = false
    @State private var showSchedulePopover = false
    @State private var showTagsPopover = false
    @State private var showLocationPopover = false
    @State private var calendarSyncErrorMessage: String?
    @State private var isSchedulingOnSave = false
    @State private var locationName: String?
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var subtaskTexts: [String] = []
    @State private var newSubtaskText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Smart NL input
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("Describe your task…", text: $smartInput)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.medium))
                    .onSubmit { applySmartInput() }
                    .onChange(of: smartInput) { _, newValue in
                        scheduleSmartParse(newValue)
                    }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)

            // Show parsed title if different from input
            if !title.isEmpty && title != smartInput {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.quaternary)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }

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
                            .frame(minWidth: 40, alignment: .leading)
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
                        .frame(width: 260)
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
                            .frame(minWidth: 48, alignment: .leading)
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
                        .frame(width: 260)
                        .padding(4)
                }
                
                // Inline date badges
                if isLater {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Later")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if isEvening {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.indigo)
                        Text("This Evening")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.indigo)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let date = whenDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                        Button {
                            whenDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let dl = deadline {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(dl.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                        Button {
                            deadline = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Location badge
            if let loc = locationName, !loc.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text(loc)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                    Button {
                        locationName = nil
                        locationLatitude = nil
                        locationLongitude = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.08), in: Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }

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
            
            // Subtasks
            if !subtaskTexts.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(subtaskTexts.enumerated()), id: \.offset) { index, text in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                            TextField("Subtask", text: Binding(
                                get: { subtaskTexts[index] },
                                set: { subtaskTexts[index] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .onSubmit {
                                if subtaskTexts[index].trimmingCharacters(in: .whitespaces).isEmpty {
                                    subtaskTexts.remove(at: index)
                                } else {
                                    subtaskTexts.append("")
                                }
                            }
                            Spacer()
                            Button {
                                subtaskTexts.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
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

                    // Location popover
                    Button {
                        showLocationPopover.toggle()
                    } label: {
                        Image(systemName: locationName != nil ? "location.fill" : "location")
                            .font(.system(size: 14))
                            .foregroundStyle(showLocationPopover ? .primary : (locationName != nil ? .primary : .tertiary))
                            .frame(width: 30, height: 28)
                            .background(showLocationPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showLocationPopover, arrowEdge: .top) {
                        quickEntryLocationPanel
                            .frame(width: 260)
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

                    // Subtasks
                    Button {
                        addSubtaskField()
                    } label: {
                        Image(systemName: !subtaskTexts.isEmpty ? "checklist.checked" : "checklist")
                            .font(.system(size: 14))
                            .foregroundStyle(!subtaskTexts.isEmpty ? .primary : .tertiary)
                            .frame(width: 30, height: 28)
                    }
                    .buttonStyle(.plain)
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
                        isLater = false
                    }

                    quickPickButton(icon: "moon.fill", iconColor: .indigo, label: "Tonight", isSelected: isEvening) {
                        whenDate = Calendar.current.startOfDay(for: .now)
                        isEvening = true
                        isLater = false
                    }

                    quickPickButton(icon: "moon.zzz.fill", iconColor: .secondary, label: "Later", isSelected: isLater) {
                        isLater = true
                        whenDate = nil
                        isEvening = false
                    }

                    if whenDate != nil || isEvening || isLater {
                        quickPickButton(icon: "xmark", iconColor: .secondary, label: "Clear", isSelected: false) {
                            whenDate = nil
                            isEvening = false
                            isLater = false
                        }
                    }
                }

                CalendarGrid(
                    selectedDate: deadline,
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

                // Deadline controls: time toggle + clear
                if deadline != nil {
                    HStack(spacing: 6) {
                        if showDeadlineTime {
                            deadlineTimeControls(deadline: deadline!)
                        } else {
                            Button {
                                showDeadlineTime = true
                                let cal = Calendar.current
                                let hour = cal.component(.hour, from: deadline!)
                                if hour == 0 {
                                    deadline = cal.date(bySettingHour: 9, minute: 0, second: 0, of: deadline!)
                                }
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
                                deadline = Calendar.current.startOfDay(for: deadline!)
                            } label: {
                                Text("Remove time")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            deadline = nil
                            showDeadlineTime = false
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
                } else {
                    Button {
                        showDeadlineTime = true
                        deadline = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
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

                Divider()
                    .padding(.top, 2)

                // Calendar section
                calendarDurationRow

                HStack(spacing: 8) {
                    Button {
                        if shouldScheduleOnSave {
                            shouldScheduleOnSave = false
                        } else {
                            ensureCalendarStartForScheduling()
                            shouldScheduleOnSave = true
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: shouldScheduleOnSave ? "checkmark.circle.fill" : "calendar.badge.plus")
                                .font(.system(size: 11, weight: .medium))
                            Text(shouldScheduleOnSave ? "Added" : "Add to Calendar")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(shouldScheduleOnSave ? Color.green : Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if shouldScheduleOnSave || (deadline != nil && dateHasExplicitTime(deadline!)) {
                        Text(calendarSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if shouldScheduleOnSave {
                        Button(role: .destructive) {
                            shouldScheduleOnSave = false
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
    }

    // MARK: - Location Panel (popover content)

    private var quickEntryLocationPanel: some View {
        QuickEntryLocationPanel(
            locationName: $locationName,
            locationLatitude: $locationLatitude,
            locationLongitude: $locationLongitude,
            isPresented: $showLocationPopover
        )
    }

    private func addSubtaskField() {
        subtaskTexts.append("")
        // Focus will be handled by the inline editor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Trigger the subtask input area to show
        }
    }

    // MARK: - Tags Panel (popover content)

    private var tagsPanel: some View {
        QuickEntryTagPanel(allTags: allTags, selectedTags: $selectedTags, modelContext: modelContext)
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
    
    // MARK: - Area Panel

    private var areaPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Area")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }

            Button {
                selectedAreaID = nil
                showAreaPopover = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedAreaID == nil ? "checkmark.circle.fill" : "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(selectedAreaID == nil ? .green : .secondary)
                    Text("No area")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(selectedAreaID == nil ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if !areas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Areas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(areas) { area in
                            Button {
                                selectedAreaID = area.id
                                showAreaPopover = false
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
                                    if selectedAreaID == area.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(selectedAreaID == area.id ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 240)
        .padding(16)
    }

    // MARK: - Project Panel

    private var projectPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Project")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }

            Button {
                selectedProjectID = nil
                showProjectPopover = false
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedProjectID == nil ? "checkmark.circle.fill" : "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(selectedProjectID == nil ? .green : .secondary)
                    Text("No project")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(selectedProjectID == nil ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if !filteredProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Projects")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(filteredProjects) { project in
                                Button {
                                    selectedProjectID = project.id
                                    showProjectPopover = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "paperplane")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: project.tintHex))
                                            .frame(width: 14)
                                        Text(project.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedProjectID == project.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(selectedProjectID == project.id ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
        .frame(minWidth: 240)
        .padding(16)
    }

    private var filteredProjects: [Project] {
        if let selectedAreaID {
            return projects.filter { $0.area?.id == selectedAreaID }
        }
        return projects
    }
    
    // MARK: - Smart Parse

    @State private var smartParseTask: Task<Void, Never>?

    private func scheduleSmartParse(_ input: String) {
        smartParseTask?.cancel()
        smartParseTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                await MainActor.run { title = "" }
                return
            }

            let parsed = smartParse(trimmed)
            await MainActor.run {
                title = parsed.title
                if let date = parsed.whenDate { whenDate = date }
                if let dl = parsed.deadline { deadline = dl }
                if parsed.isEvening { isEvening = true; whenDate = Calendar.current.startOfDay(for: .now) }
                if let time = parsed.timeOfDay { calendarStartAt = time }
                if let areaName = parsed.areaName {
                    selectedAreaID = areas.first(where: { $0.title.lowercased() == areaName.lowercased() })?.id
                }
                if let projName = parsed.projectName {
                    selectedProjectID = projects.first(where: { $0.title.lowercased() == projName.lowercased() })?.id
                }
            }

            // Refine with categorization service if no area/project matched locally
            let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
            if !apiKey.isEmpty && parsed.areaName == nil && parsed.projectName == nil {
                let categorizer = CategorizationService()
                let result = await categorizer.categorize(
                    title: parsed.title,
                    notes: "",
                    areas: areas.map { (name: $0.title, description: $0.notes) },
                    projects: projects.map { (name: $0.title, areaName: $0.area?.title) },
                    apiKey: apiKey
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if let a = result.area {
                        selectedAreaID = areas.first(where: { $0.title.lowercased() == a.lowercased() })?.id
                    }
                    if let p = result.project {
                        selectedProjectID = projects.first(where: { $0.title.lowercased() == p.lowercased() })?.id
                    }
                }
            }
        }
    }

    private func applySmartInput() {
        // The parse already ran via onChange — just ensure title is set
        if title.isEmpty {
            title = smartInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func smartParse(_ input: String) -> (title: String, whenDate: Date?, deadline: Date?, timeOfDay: Date?, isEvening: Bool, areaName: String?, projectName: String?) {
        let lower = input.lowercased()
        var t = input
        var whenDate: Date?
        var deadline: Date?
        var timeOfDay: Date?
        var isEvening = false
        var areaName: String?
        var projectName: String?
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Date extraction
        if lower.contains("this evening") || lower.contains("tonight") {
            isEvening = true; whenDate = today
            t = t.replacingOccurrences(of: "this evening", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "tonight", with: "", options: .caseInsensitive)
        } else if lower.contains("tomorrow") {
            whenDate = cal.date(byAdding: .day, value: 1, to: today)
            t = t.replacingOccurrences(of: "tomorrow", with: "", options: .caseInsensitive)
        } else if lower.contains("today") {
            whenDate = today
            t = t.replacingOccurrences(of: "today", with: "", options: .caseInsensitive)
        } else if lower.contains("next week") {
            whenDate = cal.date(byAdding: .weekOfYear, value: 1, to: today)
            t = t.replacingOccurrences(of: "next week", with: "", options: .caseInsensitive)
        }

        // Weekdays
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (idx, day) in weekdays.enumerated() {
            if lower.contains(day) {
                let target = idx + 1
                let current = cal.component(.weekday, from: today)
                let ahead = (target - current + 7) % 7
                whenDate = cal.date(byAdding: .day, value: ahead == 0 ? 7 : ahead, to: today)
                if let r = t.range(of: day, options: .caseInsensitive) { t.removeSubrange(r) }
                t = t.replacingOccurrences(of: "on ", with: " ", options: .caseInsensitive)
                break
            }
        }

        // Time extraction
        let timePatterns: [(String, Bool)] = [
            (#"\bat\s+(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#, true),
            (#"\bat\s+(\d{1,2})\s*(am|pm|AM|PM)"#, false),
            (#"(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#, true),
            (#"(\d{1,2})\s*(am|pm|AM|PM)\b"#, false),
        ]
        for (pattern, hasMins) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) {
                let hourR = Range(match.range(at: 1), in: t)!
                var hour = Int(t[hourR]) ?? 0
                let minute: Int
                if hasMins, let minR = Range(match.range(at: 2), in: t) {
                    minute = Int(t[minR]) ?? 0
                    let ampmR = Range(match.range(at: 3), in: t)!
                    if String(t[ampmR]).lowercased() == "pm" && hour < 12 { hour += 12 }
                    if String(t[ampmR]).lowercased() == "am" && hour == 12 { hour = 0 }
                } else {
                    minute = 0
                    let ampmR = Range(match.range(at: 2), in: t)!
                    if String(t[ampmR]).lowercased() == "pm" && hour < 12 { hour += 12 }
                    if String(t[ampmR]).lowercased() == "am" && hour == 12 { hour = 0 }
                }
                let base = whenDate ?? today
                timeOfDay = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)
                if whenDate == nil { whenDate = today }
                if let r = Range(match.range, in: t) { t.removeSubrange(r) }
                break
            }
        }

        // "morning" / "afternoon"
        if timeOfDay == nil {
            let base = whenDate ?? today
            if lower.contains("morning") {
                timeOfDay = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base)
                t = t.replacingOccurrences(of: "in the morning", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "morning", with: "", options: .caseInsensitive)
            } else if lower.contains("afternoon") {
                timeOfDay = cal.date(bySettingHour: 14, minute: 0, second: 0, of: base)
                t = t.replacingOccurrences(of: "in the afternoon", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "afternoon", with: "", options: .caseInsensitive)
            }
        }

        // Deadline
        if let byRange = lower.range(of: #"\bby\s+(tomorrow|today|next week|\w+day)"#, options: .regularExpression) {
            let byStr = String(lower[byRange]).replacingOccurrences(of: "by ", with: "")
            if byStr == "tomorrow" { deadline = cal.date(byAdding: .day, value: 1, to: today) }
            else if byStr == "today" { deadline = today }
            else if byStr == "next week" { deadline = cal.date(byAdding: .weekOfYear, value: 1, to: today) }
            if let r = t.range(of: #"\bby\s+(tomorrow|today|next week|\w+day)"#, options: [.regularExpression, .caseInsensitive]) {
                t.removeSubrange(r)
            }
        }

        // Urgency words
        for word in ["urgent", "asap", "important", "critical", "emergency"] {
            t = t.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        t = t.replacingOccurrences(of: #"\b(it(?:'s| is)\s+)?really\s*"#, with: "", options: [.regularExpression, .caseInsensitive])

        // Project/Area extraction
        for prep in ["for ", "in "] {
            if let range = t.lowercased().range(of: prep, options: .backwards) {
                let after = String(t.lowercased()[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let proj = projects.first(where: { after.contains($0.title.lowercased()) }) {
                    projectName = proj.title; areaName = proj.area?.title
                    if let r = t.range(of: prep + proj.title, options: .caseInsensitive) { t.removeSubrange(r) }
                    break
                }
                if let area = areas.first(where: { after.contains($0.title.lowercased()) }) {
                    areaName = area.title
                    if let r = t.range(of: prep + area.title, options: .caseInsensitive) { t.removeSubrange(r) }
                    break
                }
            }
        }

        // Distill title
        // Strip leading filler
        let fillers = [
            #"^i\s+(?:need|want|have|got|should|must|gotta)\s+(?:to\s+)?"#,
            #"^i(?:'ve| have)\s+(?:got\s+)?(?:a|an|the|my)\s+"#,
            #"^(?:i\s+)?(?:need|want|have)\s+(?:a|an|the|my)\s+"#,
            #"^remind\s+me\s+(?:to\s+)?"#,
            #"^(?:add|create)\s+(?:a\s+)?(?:task\s+(?:to|for)\s+)?"#,
            #"^(?:please|pls)\s+"#,
            #"^(?:don't\s+forget\s+(?:to\s+)?)"#,
        ]
        for pattern in fillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let r = Range(match.range, in: t) { t.removeSubrange(r); break }
        }
        // Strip trailing filler
        let trailingFillers = [
            #"\s+(?:that\s+)?(?:i\s+)?(?:really\s+)?(?:need|have|want|got)\s+to\s+(?:get\s+)?(?:done|do|finish|complete).*$"#,
            #"\s+(?:in\s+the\s+)?(?:morning|afternoon|evening)$"#,
            #"\s+(?:as\s+soon\s+as\s+possible|asap)$"#,
        ]
        for pattern in trailingFillers {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let r = Range(match.range, in: t) { t.removeSubrange(r) }
        }
        t = t.replacingOccurrences(of: #"^(?:a|an|the|my)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: #"^[\s,;:\-–—]+|[\s,;:\-–—]+$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize
        if let first = t.first, first.isLowercase { t = first.uppercased() + t.dropFirst() }
        if t.isEmpty { t = input.trimmingCharacters(in: .whitespacesAndNewlines) }

        return (t, whenDate, deadline, timeOfDay, isEvening, areaName, projectName)
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
            whenDate: isLater ? nil : resolvedWhen,
            deadline: deadline,
            status: isLater ? .someday : .active,
            isInInbox: !isLater && resolvedArea == nil && selectedProject == nil,
            isEvening: isEvening || routing.shouldMarkEvening,
            calendarStartAt: shouldScheduleOnSave ? calendarStartAt : nil,
            calendarDurationMinutes: calendarDurationBinding.wrappedValue,
            area: resolvedArea,
            project: selectedProject
        )
        task.locationName = locationName
        task.locationLatitude = locationLatitude
        task.locationLongitude = locationLongitude
        modelContext.insert(task)
        for tag in selectedTags {
            let assignment = TaskTagAssignment(task: task, tag: tag)
            modelContext.insert(assignment)
        }
        let validSubtasks = subtaskTexts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for (i, text) in validSubtasks.enumerated() {
            let item = ChecklistItem(title: text, sortOrder: Double(i), task: task)
            modelContext.insert(item)
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

// MARK: - QuickEntryLocationPanel

private struct QuickEntryLocationPanel: View {
    @Binding var locationName: String?
    @Binding var locationLatitude: Double?
    @Binding var locationLongitude: Double?
    @Binding var isPresented: Bool

    @StateObject private var completer = LocationCompleterModel()
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Search location…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onChange(of: searchText) { _, newValue in
                        completer.search(query: newValue)
                    }
            }
            .padding(8)

            if let name = locationName, !name.isEmpty, searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        locationName = nil
                        locationLatitude = nil
                        locationLongitude = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            if !completer.results.isEmpty && !searchText.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(completer.results.prefix(6), id: \.self) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
        }
        .padding(4)
    }

    private func selectResult(_ result: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let item = response?.mapItems.first else {
                Task { @MainActor in
                    locationName = result.title
                    locationLatitude = nil
                    locationLongitude = nil
                    searchText = ""
                }
                return
            }
            Task { @MainActor in
                locationName = item.name ?? result.title
                locationLatitude = item.placemark.coordinate.latitude
                locationLongitude = item.placemark.coordinate.longitude
                searchText = ""
            }
        }
    }
}
