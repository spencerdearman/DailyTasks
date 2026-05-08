//
//  QuickEntrySheet.swift
//  FluxApp
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
    @State private var showWhenPicker = false

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
                        TextField("What do you need to do?", text: $title)
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
                    VStack(spacing: 0) {
                        // When row
                        Button {
                            showWhenPicker = true
                        } label: {
                            HStack {
                                Image(systemName: whenIcon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(whenColor == .secondary ? Color.secondary : Color.white)
                                    .frame(width: 30, height: 30)
                                    .background(whenColor, in: Circle())
                                Text("When")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(whenLabel)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showWhenPicker, arrowEdge: .top) {
                            whenPickerPopover
                                .presentationCompactAdaptation(.popover)
                        }

                        Divider().padding(.leading, 52)

                        // Deadline
                        HStack {
                            Label("Deadline", systemImage: "flag.fill")
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
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
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Organize
                    sectionHeader("Organize")
                    VStack(spacing: 0) {
                        HStack {
                            Label("Area", systemImage: "square.grid.2x2")
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                            Picker("", selection: $selectedAreaID) {
                                Text("Inbox").tag(UUID?.none)
                                ForEach(areas) { area in
                                    Text(area.title).tag(Optional(area.id))
                                }
                            }
                            .labelsHidden()
                            .tint(.secondary)
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 52)

                        HStack {
                            Label("Project", systemImage: "paperplane")
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                            Picker("", selection: $selectedProjectID) {
                                Text("None").tag(UUID?.none)
                                ForEach(filteredProjects) { project in
                                    Text(project.title).tag(Optional(project.id))
                                }
                            }
                            .labelsHidden()
                            .tint(.secondary)
                            .lineLimit(1)
                            .disabled(selectedAreaID == nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    // MARK: - When Picker Popover

    private var whenPickerPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            whenPickerRow(icon: "star.fill", color: .yellow, label: "Today",
                isSelected: whenDate != nil && Calendar.current.isDateInToday(whenDate!) && !isEvening) {
                whenDate = Calendar.current.startOfDay(for: .now)
                isEvening = false
                status = .active
                showWhenPicker = false
            }

            Divider().padding(.leading, 56)

            whenPickerRow(icon: "moon.fill", color: .indigo, label: "This Evening",
                isSelected: isEvening) {
                whenDate = Calendar.current.startOfDay(for: .now)
                isEvening = true
                status = .active
                showWhenPicker = false
            }

            Divider().padding(.leading, 56)

            whenPickerRow(icon: "clock", color: .teal, label: "Later",
                isSelected: {
                    guard let w = whenDate else { return false }
                    return !Calendar.current.isDateInToday(w) && !isEvening
                }()) {
                whenDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                isEvening = false
                status = .active
                showWhenPicker = false
            }

            if whenDate != nil || isEvening {
                Divider()

                whenPickerRow(icon: "xmark", color: .gray, label: "Clear",
                    isSelected: false) {
                    whenDate = nil
                    isEvening = false
                    showWhenPicker = false
                }
            }
        }
        .padding(.vertical, 4)
        .frame(width: 220)
    }

    private func whenPickerRow(icon: String, color: Color, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: Circle())

                Text(label)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}
