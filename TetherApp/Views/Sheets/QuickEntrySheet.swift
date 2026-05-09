//
//  QuickEntrySheet.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - QuickEntrySheet

/// A sheet for quickly creating a new task with optional placement and timing.
struct QuickEntrySheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \Area.sortOrder) private var areas: [Area]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    // MARK: - Properties

    private let eventKitSync = EventKitSyncService()

    let defaultSelection: SidebarSelection?

    // MARK: - State

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var whenDate: Date?
    @State private var deadline: Date?
    @State private var isEvening = false
    @State private var status: TaskStatus = .active
    @State private var durationMinutes: Int = 60
    @State private var isSyncingCalendarEvent = false
    @State private var calendarSyncMessage: String?
    @State private var calendarSyncError = false

    // MARK: - Computed

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var whenLabel: String {
        if isEvening { return "This Evening" }
        guard let w = whenDate else { return "None" }
        if Calendar.current.isDateInToday(w) { return "Today" }
        if Calendar.current.isDateInTomorrow(w) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: w)
    }

    private var whenIcon: String {
        if isEvening { return "moon.fill" }
        guard let w = whenDate else { return "calendar" }
        if Calendar.current.isDateInToday(w) { return "star.fill" }
        return "clock"
    }

    private var whenColor: Color {
        if isEvening { return .indigo }
        guard let w = whenDate else { return .secondary }
        if Calendar.current.isDateInToday(w) { return .yellow }
        return .teal
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Title & Notes
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("New task", text: $title)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        TextField("Notes", text: $notes, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2...8)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Schedule
                    sectionHeader("Schedule")
                    scheduleCard

                    // Organize
                    sectionHeader("Organize")
                    placementSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTask()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: applyDefaultSelection)
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

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.top, 12)
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // When row
            HStack {
                Image(systemName: whenIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("When")
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button {
                        whenDate = Calendar.current.startOfDay(for: .now)
                        isEvening = false
                        status = .active
                    } label: {
                        Label("Today", systemImage: "star.fill")
                        if whenDate != nil && Calendar.current.isDateInToday(whenDate!) && !isEvening {
                            Image(systemName: "checkmark")
                        }
                    }
                    Button {
                        whenDate = Calendar.current.startOfDay(for: .now)
                        isEvening = true
                        status = .active
                    } label: {
                        Label("This Evening", systemImage: "moon.fill")
                        if isEvening {
                            Image(systemName: "checkmark")
                        }
                    }
                    Button {
                        whenDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                        isEvening = false
                        status = .active
                    } label: {
                        Label("Later", systemImage: "clock")
                        if let w = whenDate, !Calendar.current.isDateInToday(w) && !isEvening {
                            Image(systemName: "checkmark")
                        }
                    }
                    if whenDate != nil || isEvening {
                        Divider()
                        Button {
                            whenDate = nil
                            isEvening = false
                        } label: {
                            Label("Clear", systemImage: "xmark")
                        }
                    }
                } label: {
                    Text(whenLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 52)

            // Deadline
            HStack {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("Deadline")
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    deadline = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .opacity(deadline != nil ? 1 : 0)
                .allowsHitTesting(deadline != nil)

                DatePicker("", selection: deadlineBinding, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            // Duration
            Stepper(value: $durationMinutes, in: 15...480, step: 15) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Duration")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(durationMinutes) min")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            // Calendar action row
            Button {
                scheduleOnCalendar()
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .disabled(isSyncingCalendarEvent || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Placement (Area / Project)

    private var placementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Area row
            HStack {
                Image(systemName: selectedAreaIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("Area")
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button {
                        selectedAreaID = nil
                        selectedProjectID = nil
                    } label: {
                        Label("Inbox", systemImage: "tray.fill")
                        if selectedAreaID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                    ForEach(areas) { area in
                        Button {
                            selectedAreaID = area.id
                            selectedProjectID = nil
                        } label: {
                            Label(area.title, systemImage: area.symbolName)
                            if selectedAreaID == area.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Text(selectedAreaLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 62)

            // Project row
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("Project")
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    Button {
                        selectedProjectID = nil
                    } label: {
                        Label("None", systemImage: "minus.circle")
                        if selectedProjectID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                    ForEach(filteredProjects) { project in
                        Button {
                            selectedProjectID = project.id
                        } label: {
                            Label(project.title, systemImage: "paperplane")
                            if selectedProjectID == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Text(selectedProjectLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                .disabled(selectedAreaID == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var selectedAreaLabel: String {
        guard let selectedAreaID else { return "Inbox" }
        return areas.first(where: { $0.id == selectedAreaID })?.title ?? "Inbox"
    }

    private var selectedAreaIcon: String {
        guard let selectedAreaID else { return "tray.fill" }
        return areas.first(where: { $0.id == selectedAreaID })?.symbolName ?? "tray.fill"
    }

    private var selectedAreaColor: Color {
        guard let selectedAreaID, let area = areas.first(where: { $0.id == selectedAreaID }) else { return .secondary }
        return Color(hex: area.tintHex)
    }

    private var selectedProjectLabel: String {
        guard let selectedProjectID else { return "None" }
        return projects.first(where: { $0.id == selectedProjectID })?.title ?? "None"
    }

    // MARK: - Computed Properties

    private var filteredProjects: [Project] {
        guard let selectedAreaID else { return [] }
        return projects.filter { $0.area?.id == selectedAreaID }
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { deadline ?? .now },
            set: { deadline = $0 }
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

    // MARK: - Actions

    private func applyDefaultSelection() {
        guard selectedAreaID == nil, selectedProjectID == nil else { return }

        switch defaultSelection {
        case .area(let id):
            selectedAreaID = id
        case .project(let id):
            selectedProjectID = id
            selectedAreaID = projects.first(where: { $0.id == id })?.area?.id
        case .someday:
            status = .someday
        default:
            break
        }
    }

    private func saveTask() {
        let project = projects.first(where: { $0.id == selectedProjectID })
        let area = project?.area ?? areas.first(where: { $0.id == selectedAreaID })
        let task = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            whenDate: whenDate,
            deadline: deadline,
            status: status,
            isInInbox: area == nil && project == nil,
            isEvening: isEvening,
            sortOrder: Double((project?.taskList.count ?? area?.taskList.count ?? 0)),
            area: area,
            project: project
        )
        task.calendarDurationMinutes = durationMinutes
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }

    private func scheduleOnCalendar() {
        guard canSave else { return }
        isSyncingCalendarEvent = true

        // Save the task first so we have something to attach the event to
        let project = projects.first(where: { $0.id == selectedProjectID })
        let area = project?.area ?? areas.first(where: { $0.id == selectedAreaID })
        let task = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            whenDate: whenDate,
            deadline: deadline,
            status: status,
            isInInbox: area == nil && project == nil,
            isEvening: isEvening,
            sortOrder: Double((project?.taskList.count ?? area?.taskList.count ?? 0)),
            area: area,
            project: project
        )
        task.calendarDurationMinutes = durationMinutes
        if let dl = deadline {
            task.calendarStartAt = dl
            task.whenDate = Calendar.current.startOfDay(for: dl)
        }
        modelContext.insert(task)
        try? modelContext.save()

        Task {
            do {
                try await eventKitSync.upsertCalendarEvent(for: task)
                try? modelContext.save()
                calendarSyncError = false
                calendarSyncMessage = "The task was scheduled on your calendar."
            } catch {
                calendarSyncError = true
                calendarSyncMessage = error.localizedDescription
            }
            isSyncingCalendarEvent = false
            dismiss()
        }
    }
}
