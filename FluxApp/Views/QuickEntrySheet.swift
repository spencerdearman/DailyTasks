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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("New task", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Placement") {
                    Picker("Area", selection: $selectedAreaID) {
                        Text("Inbox").tag(UUID?.none)
                        ForEach(areas) { area in
                            Text(area.title).tag(Optional(area.id))
                        }
                    }

                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(UUID?.none)
                        ForEach(filteredProjects) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    .disabled(selectedAreaID == nil)
                }

                Section("Timing") {
                    Picker("Status", selection: $status) {
                        Text("Active").tag(TaskStatus.active)
                        Text("Later").tag(TaskStatus.someday)
                    }

                    Toggle("This Evening", isOn: $isEvening)
                    DatePicker("When", selection: whenBinding, displayedComponents: .date)
                    DatePicker("Deadline", selection: deadlineBinding, displayedComponents: [.date, .hourAndMinute])

                    Button("Clear When") {
                        whenDate = nil
                        isEvening = false
                    }

                    Button("Clear Deadline") {
                        deadline = nil
                    }
                }
            }
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: applyDefaultSelection)
        }
    }

    // MARK: - Computed Properties

    private var filteredProjects: [Project] {
        guard let selectedAreaID else { return [] }
        return projects.filter { $0.area?.id == selectedAreaID }
    }

    private var whenBinding: Binding<Date> {
        Binding(
            get: { whenDate ?? .now },
            set: { whenDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { deadline ?? .now },
            set: { deadline = $0 }
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
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}
