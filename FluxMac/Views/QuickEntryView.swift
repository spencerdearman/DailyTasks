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
    
    let defaultSelection: SidebarSelection?
    
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var whenDate: Date?
    @State private var deadline: Date?
    @State private var isEvening = false
    @State private var selectedTags: [Tag] = []
    
    @State private var showCalendarPopover = false
    @State private var showTagsPopover = false
    @State private var showDeadlinePopover = false
    
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
                Menu {
                    Button {
                        selectedAreaID = nil
                    } label: {
                        Label("No area", systemImage: "xmark")
                    }
                    ForEach(areas) { area in
                        Button {
                            selectedAreaID = area.id
                        } label: {
                            Label(area.title, systemImage: area.symbolName)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedAreaID != nil ? (areas.first(where: { $0.id == selectedAreaID })?.symbolName ?? "square.grid.2x2") : "square.grid.2x2")
                            .font(.system(size: 11))
                            .foregroundStyle(selectedAreaID != nil ? .primary : .secondary)
                        Text(selectedAreaID != nil ? (areas.first(where: { $0.id == selectedAreaID })?.title ?? "Area") : "Area")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedAreaID != nil ? .primary : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Menu {
                    Button {
                        selectedProjectID = nil
                    } label: {
                        Label("No project", systemImage: "xmark")
                    }
                    ForEach(filteredProjects) { project in
                        Button {
                            selectedProjectID = project.id
                        } label: {
                            Label(project.title, systemImage: "paperplane")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 11))
                            .foregroundStyle(selectedProjectID != nil ? .primary : .secondary)
                        Text(selectedProjectID != nil ? (filteredProjects.first(where: { $0.id == selectedProjectID })?.title ?? "Project") : "Project")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedProjectID != nil ? .primary : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
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
                    // Calendar popover
                    Button {
                        showCalendarPopover.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(showCalendarPopover ? .primary : (whenDate != nil || isEvening ? .primary : .tertiary))
                            .frame(width: 30, height: 28)
                            .background(showCalendarPopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCalendarPopover, arrowEdge: .top) {
                        calendarPanel
                            .frame(width: 300)
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
                    
                    // Deadline popover
                    Button {
                        showDeadlinePopover.toggle()
                    } label: {
                        Image(systemName: deadline != nil ? "flag.fill" : "flag")
                            .font(.system(size: 14))
                            .foregroundStyle(showDeadlinePopover ? Color.primary : (deadline != nil ? Color.orange : Color(white: 0.6)))
                            .frame(width: 30, height: 28)
                            .background(showDeadlinePopover ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDeadlinePopover, arrowEdge: .top) {
                        deadlinePanel
                            .frame(width: 300)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 440)
        .background(.ultraThinMaterial)
        .onAppear(perform: configureDefaults)
    }
    
    // MARK: - Calendar Panel (popover content)
    
    private var calendarPanel: some View {
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
                
                if whenDate != nil || isEvening {
                    quickPickButton(icon: "xmark", iconColor: .secondary, label: "Clear", isSelected: false) {
                        whenDate = nil
                        isEvening = false
                    }
                }
            }
            
            CalendarGrid(
                selectedDate: whenDate,
                onSelect: { date in
                    whenDate = date
                    isEvening = false
                }
            )
        }
        .frame(minWidth: 280)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Tags Panel (popover content)
    
    private var tagsPanel: some View {
        QuickEntryTagPanel(allTags: allTags, selectedTags: $selectedTags, modelContext: modelContext)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Deadline Panel (popover content)
    
    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text("Deadline")
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                if deadline != nil {
                    Button {
                        deadline = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Clear")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            CalendarGrid(
                selectedDate: deadline,
                accentColor: .orange,
                onSelect: { date in
                    deadline = date
                }
            )
        }
        .frame(minWidth: 280)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .frame(width: 64, height: 48)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
    
    private func saveTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let selectedArea = areas.first(where: { $0.id == selectedAreaID })
        let selectedProject = projects.first(where: { $0.id == selectedProjectID })
        let routing = SemanticRouter.analyze(title: normalizedTitle, notes: normalizedNotes, areas: areas)
        
        let resolvedArea = selectedArea ?? selectedProject?.area ?? routing.matchedArea
        let resolvedWhen = whenDate ?? routing.suggestedWhen
        let task = TaskItem(
            title: normalizedTitle,
            notes: normalizedNotes,
            whenDate: resolvedWhen,
            deadline: deadline,
            isInInbox: resolvedArea == nil && selectedProject == nil,
            isEvening: isEvening || routing.shouldMarkEvening,
            area: resolvedArea,
            project: selectedProject
        )
        modelContext.insert(task)
        for tag in selectedTags {
            let assignment = TaskTagAssignment(task: task, tag: tag)
            modelContext.insert(assignment)
        }
        try? modelContext.save()
        dismiss()
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
