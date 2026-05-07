//
//  TaskEditorSheet.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskEditorSheet

/// A detail editor sheet for modifying an existing task's properties, schedule, and calendar sync.
struct TaskEditorSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    // MARK: - Properties

    private let eventKitSync = EventKitSyncService()

    @Bindable var task: TaskItem

    // MARK: - State

    @State private var showDeleteConfirm = false
    @State private var calendarSyncMessage: String?
    @State private var calendarSyncError = false
    @State private var isSyncingCalendarEvent = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleAndNotesSection
                    checklistSection
                    placementSection
                    scheduleQuickPicksSection
                    deadlineAndCalendarSection
                    deleteSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(task.title.isEmpty ? "Task" : task.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        task.updatedAt = .now
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(task)
                    try? modelContext.save()
                    dismiss()
                }
            }
            .alert(calendarSyncError ? "Calendar Sync Failed" : "Calendar Updated", isPresented: alertIsPresented) {
                Button("OK", role: .cancel) {
                    calendarSyncMessage = nil
                    calendarSyncError = false
                }
            } message: {
                Text(calendarSyncMessage ?? "")
            }
        }
    }

    // MARK: - Title & Notes

    private var titleAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Task title", text: $task.title)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            TextField("Add notes…", text: $task.notes, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2...10)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Checklist

    @ViewBuilder
    private var checklistSection: some View {
        if !task.checklistItems.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            item.isCompleted.toggle()
                            try? modelContext.save()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                                .font(.title3)
                            Text(item.title)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if item.id != task.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder }).last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Placement (Area / Project)

    private var placementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Area", systemImage: "square.grid.2x2")
                    .foregroundStyle(.primary)
                Spacer()
                Picker("", selection: areaBinding) {
                    Text("Inbox").tag(UUID?.none)
                    ForEach(areas) { area in
                        Text(area.title).tag(Optional(area.id))
                    }
                }
                .labelsHidden()
                .tint(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            HStack {
                Label("Project", systemImage: "paperplane")
                    .foregroundStyle(.primary)
                Spacer()
                Picker("", selection: projectBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(filteredProjects) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .tint(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Schedule Quick Picks

    private var scheduleQuickPicksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                scheduleQuickButton(icon: "star.fill", iconColor: .yellow, label: "Today",
                    isSelected: task.whenDate != nil && Calendar.current.isDateInToday(task.whenDate!) && !task.isEvening) {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = false
                    task.status = .active
                    task.updatedAt = .now
                }

                scheduleQuickButton(icon: "moon.fill", iconColor: .indigo, label: "Evening",
                    isSelected: task.isEvening) {
                    task.whenDate = Calendar.current.startOfDay(for: .now)
                    task.isEvening = true
                    task.status = .active
                    task.updatedAt = .now
                }

                scheduleQuickButton(icon: "clock", iconColor: .teal, label: "Later",
                    isSelected: {
                        guard let w = task.whenDate else { return false }
                        return !Calendar.current.isDateInToday(w) && !task.isEvening
                    }()) {
                    task.whenDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                    task.isEvening = false
                    task.status = .active
                    task.updatedAt = .now
                }

                if task.whenDate != nil || task.isEvening {
                    scheduleQuickButton(icon: "xmark", iconColor: .secondary, label: "Clear", isSelected: false) {
                        task.whenDate = nil
                        task.isEvening = false
                        task.updatedAt = .now
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Deadline & Calendar

    private var deadlineAndCalendarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Deadline
            HStack {
                Label("Deadline", systemImage: "flag.fill")
                    .foregroundStyle(.primary)
                Spacer()
                if task.deadline != nil {
                    Button {
                        task.deadline = nil
                        task.updatedAt = .now
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
                DatePicker("", selection: deadlineBinding, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            // Duration
            Stepper(value: $task.calendarDurationMinutes, in: 15...480, step: 15) {
                HStack {
                    Label("Duration", systemImage: "timer")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(task.calendarDurationMinutes) min")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            // Calendar action row
            HStack {
                Button {
                    scheduleOnCalendar()
                } label: {
                    Label(
                        task.hasCalendarEvent ? "Update Calendar" : "Add to Calendar",
                        systemImage: task.hasCalendarEvent ? "calendar.badge.checkmark" : "calendar.badge.plus"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.hasCalendarEvent ? .green : .blue)
                }
                .buttonStyle(.plain)
                .disabled(isSyncingCalendarEvent || task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if task.hasCalendarEvent {
                    Button(role: .destructive) {
                        removeFromCalendar()
                    } label: {
                        Text("Remove")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncingCalendarEvent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                Label("Delete Task", systemImage: "trash")
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Computed Properties

    private var filteredProjects: [Project] {
        guard let areaID = task.area?.id else { return [] }
        return projects.filter { $0.area?.id == areaID }
    }

    // MARK: - Bindings

    private var areaBinding: Binding<UUID?> {
        Binding(
            get: { task.area?.id },
            set: { newValue in
                task.area = areas.first(where: { $0.id == newValue })
                if let area = task.area {
                    task.isInInbox = false
                    if let project = task.project, project.area?.id != area.id {
                        task.project = nil
                    }
                } else {
                    task.project = nil
                    task.isInInbox = true
                }
                task.updatedAt = .now
            }
        )
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { task.project?.id },
            set: { newValue in
                task.project = projects.first(where: { $0.id == newValue })
                if let project = task.project {
                    task.area = project.area
                    task.isInInbox = false
                }
                task.updatedAt = .now
            }
        )
    }

    private var whenBinding: Binding<Date> {
        Binding(
            get: { task.whenDate ?? .now },
            set: {
                task.whenDate = Calendar.current.startOfDay(for: $0)
                task.status = .active
                task.updatedAt = .now
            }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { task.deadline ?? .now },
            set: {
                task.deadline = $0
                task.updatedAt = .now
            }
        )
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { calendarSyncMessage != nil },
            set: { presented in
                if !presented {
                    calendarSyncMessage = nil
                    calendarSyncError = false
                }
            }
        )
    }

    // MARK: - Calendar Actions

    private func scheduleOnCalendar() {
        isSyncingCalendarEvent = true

        // Use deadline as calendar start time
        if let deadline = task.deadline {
            task.calendarStartAt = deadline
            task.whenDate = Calendar.current.startOfDay(for: deadline)
        }
        task.calendarDurationMinutes = max(task.calendarDurationMinutes, 15)
        task.updatedAt = .now

        Task {
            do {
                task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                task.notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                try await eventKitSync.upsertCalendarEvent(for: task)
                try? modelContext.save()
                calendarSyncError = false
                calendarSyncMessage = task.hasCalendarEvent
                    ? "The calendar event is linked and will stay explicit unless you update it again here."
                    : "The task was scheduled on your calendar."
            } catch {
                calendarSyncError = true
                calendarSyncMessage = error.localizedDescription
            }
            isSyncingCalendarEvent = false
        }
    }

    private func removeFromCalendar() {
        isSyncingCalendarEvent = true

        Task {
            do {
                try await eventKitSync.removeCalendarEvent(for: task)
                try? modelContext.save()
                calendarSyncError = false
                calendarSyncMessage = "The linked calendar event was removed."
            } catch {
                calendarSyncError = true
                calendarSyncMessage = error.localizedDescription
            }
            isSyncingCalendarEvent = false
        }
    }

    // MARK: - Schedule Quick Button

    private func scheduleQuickButton(icon: String, iconColor: Color, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : iconColor)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                isSelected ? AnyShapeStyle(iconColor) : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
