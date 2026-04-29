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

    @Query(sort: \FluxArea.sortOrder) private var areas: [FluxArea]
    @Query(sort: \FluxProject.sortOrder) private var projects: [FluxProject]
    @Query(sort: \FluxTag.title) private var allTags: [FluxTag]

    let defaultSelection: FluxSidebarSelection?

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var whenDate: Date?
    @State private var deadline: Date?
    @State private var isEvening = false
    @State private var selectedTags: [FluxTag] = []
    @State private var activeAction: QuickEntryAction?

    private enum QuickEntryAction: Hashable {
        case calendar, tags, deadline
    }

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
            TextEditor(text: $notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(.horizontal, 20)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Notes")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }

            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            // Area & Project pickers - styled inline
            HStack(spacing: 12) {
                Picker("", selection: $selectedAreaID) {
                    Text("No area").tag(UUID?.none)
                    ForEach(areas) { area in
                        Label(area.title, systemImage: area.symbolName).tag(Optional(area.id))
                    }
                }
                .labelsHidden()
                .fixedSize()

                Picker("", selection: $selectedProjectID) {
                    Text("No project").tag(UUID?.none)
                    ForEach(filteredProjects) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .fixedSize()

                Spacer()
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

            // Date / deadline info
            if whenDate != nil || deadline != nil || isEvening {
                HStack(spacing: 12) {
                    if isEvening {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.indigo)
                            Text("This Evening").font(.caption.weight(.medium)).foregroundStyle(.indigo)
                        }
                    } else if let date = whenDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(date.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.medium))
                        }
                        Button {
                            whenDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let dl = deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(.orange)
                            Text("Due \(dl.formatted(.dateTime.month(.abbreviated).day()))").font(.caption.weight(.medium)).foregroundStyle(.orange)
                        }
                        Button {
                            deadline = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            // Action panel
            if let action = activeAction {
                Group {
                    switch action {
                    case .calendar:
                        calendarPanel
                    case .tags:
                        tagsPanel
                    case .deadline:
                        deadlinePanel
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Bottom bar: action buttons + save
            HStack(spacing: 0) {
                // Action buttons
                HStack(spacing: 2) {
                    quickActionButton(.calendar, icon: "calendar", active: whenDate != nil || isEvening)
                    quickActionButton(.tags, icon: "tag", active: !selectedTags.isEmpty)
                    quickActionButton(.deadline, icon: "flag", active: deadline != nil)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") { saveTask() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 440)
        .background(.ultraThinMaterial)
        .onAppear(perform: configureDefaults)
    }

    private func quickActionButton(_ mode: QuickEntryAction, icon: String, active: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeAction = activeAction == mode ? nil : mode
            }
        } label: {
            Image(systemName: active ? "\(icon).fill" : icon)
                .font(.system(size: 14))
                .foregroundStyle(activeAction == mode ? .primary : (active ? .primary : .tertiary))
                .frame(width: 30, height: 28)
                .background(activeAction == mode ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    whenDate = Calendar.current.startOfDay(for: .now)
                    isEvening = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow)
                        Text("Today").font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    whenDate = Calendar.current.startOfDay(for: .now)
                    isEvening = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill").font(.system(size: 11)).foregroundStyle(.indigo)
                        Text("This Evening").font(.subheadline)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            DatePicker("", selection: Binding(
                get: { whenDate ?? .now },
                set: { whenDate = $0; isEvening = false }
            ), displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: 280, maxHeight: 240)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tagsPanel: some View {
        QuickEntryTagPanel(allTags: allTags, selectedTags: $selectedTags, modelContext: modelContext)
    }

    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker("", selection: Binding(
                get: { deadline ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now },
                set: { deadline = $0 }
            ), displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: 280, maxHeight: 240)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filteredProjects: [FluxProject] {
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

    private func saveTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let selectedArea = areas.first(where: { $0.id == selectedAreaID })
        let selectedProject = projects.first(where: { $0.id == selectedProjectID })
        let routing = FluxSemanticRouter.analyze(title: normalizedTitle, notes: normalizedNotes, areas: areas)

        let resolvedArea = selectedArea ?? selectedProject?.area ?? routing.matchedArea
        let resolvedWhen = whenDate ?? routing.suggestedWhen
        let task = FluxTask(
            title: normalizedTitle,
            notes: normalizedNotes,
            whenDate: resolvedWhen,
            deadline: deadline,
            isInInbox: resolvedArea == nil && selectedProject == nil,
            isEvening: isEvening || routing.shouldMarkEvening,
            area: resolvedArea,
            project: selectedProject
        )
        task.tags = selectedTags

        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}

private struct QuickEntryTagPanel: View {
    let allTags: [FluxTag]
    @Binding var selectedTags: [FluxTag]
    let modelContext: ModelContext

    @State private var searchText = ""

    private var filteredTags: [FluxTag] {
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
        let tag = FluxTag(title: name)
        modelContext.insert(tag)
        selectedTags.append(tag)
        try? modelContext.save()
        searchText = ""
    }
}

private extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
