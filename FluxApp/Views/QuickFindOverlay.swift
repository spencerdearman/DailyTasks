//
//  QuickFindOverlay.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - QuickFindOverlay

/// A command-palette style overlay for searching tasks, projects, areas, and lists.
struct QuickFindOverlay: View {

    // MARK: - Properties

    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let onSelectSidebar: (SidebarSelection) -> Void
    let onSelectTask: (TaskItem) -> Void
    let onDismiss: () -> Void

    // MARK: - State

    @State private var query = ""
    @State private var showPanel = false
    @FocusState private var isFocused: Bool

    // MARK: - Data

    private struct QuickFindItem: Identifiable {
        let id: String
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String?
        let action: () -> Void
    }

    private var coreListItems: [QuickFindItem] {
        let lists: [(String, String, Color, SidebarSelection)] = [
            ("Inbox", "tray.fill", .primary, .inbox),
            ("Today", "sun.max.fill", .yellow, .today),
            ("Upcoming", "calendar", .red, .upcoming),
            ("Open", "tray.2.fill", .blue, .anytime),
            ("Later", "moon.zzz.fill", .purple, .someday),
            ("Done", "checkmark.circle.fill", .green, .logbook),
        ]
        return lists.compactMap { (title, icon, color, sel) in
            guard query.isEmpty || title.localizedCaseInsensitiveContains(query) else { return nil }
            return QuickFindItem(id: "list-\(title)", icon: icon, iconColor: color, title: title, subtitle: nil) {
                onSelectSidebar(sel)
            }
        }
    }

    private var areaItems: [QuickFindItem] {
        let filtered = query.isEmpty ? areas : areas.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.map { area in
            QuickFindItem(id: "area-\(area.id)", icon: area.symbolName, iconColor: Color(hex: area.tintHex), title: area.title, subtitle: nil) {
                onSelectSidebar(.area(area.id))
            }
        }
    }

    private var projectItems: [QuickFindItem] {
        let filtered = query.isEmpty ? projects : projects.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.map { project in
            QuickFindItem(id: "project-\(project.id)", icon: "paperplane", iconColor: Color(hex: project.tintHex), title: project.title, subtitle: project.area?.title) {
                onSelectSidebar(.project(project.id))
            }
        }
    }

    private var taskItems: [QuickFindItem] {
        guard !query.isEmpty else { return [] }
        let filtered = tasks.filter { !$0.isCompleted && $0.title.localizedCaseInsensitiveContains(query) }
        return filtered.prefix(8).map { task in
            QuickFindItem(id: "task-\(task.id)", icon: "circle", iconColor: .secondary, title: task.title, subtitle: task.project?.title ?? task.area?.title) {
                onSelectTask(task)
            }
        }
    }

    private var allItems: [QuickFindItem] {
        coreListItems + areaItems + projectItems + taskItems
    }

    private var hasResults: Bool {
        !allItems.isEmpty || !query.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(showPanel ? 0.25 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
                .animation(.easeOut(duration: 0.25), value: showPanel)

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.tertiary)

                    TextField("Find", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17, weight: .light))
                        .focused($isFocused)

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.quaternary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if hasResults {
                    Divider()
                        .opacity(0.5)
                        .padding(.horizontal, 16)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !coreListItems.isEmpty {
                                quickFindSection("Lists", items: coreListItems)
                            }
                            if !areaItems.isEmpty {
                                quickFindSection("Areas", items: areaItems)
                            }
                            if !projectItems.isEmpty {
                                quickFindSection("Projects", items: projectItems)
                            }
                            if !taskItems.isEmpty {
                                quickFindSection("Tasks", items: taskItems)
                            }
                            if allItems.isEmpty && !query.isEmpty {
                                Text("No results")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 400)
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 6)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 4)
                        }
                    )
                }
            }
            .background(.background.opacity(0.85), in: .rect(cornerRadius: hasResults ? 22 : 26))
            .glassEffect(.regular, in: .rect(cornerRadius: hasResults ? 22 : 26))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .scaleEffect(showPanel ? 1 : 0.95)
            .opacity(showPanel ? 1 : 0)
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.easeOut(duration: 0.15), value: hasResults)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showPanel = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        isFocused = false
        withAnimation(.easeOut(duration: 0.2)) {
            showPanel = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - Section

    private func quickFindSection(_ title: String, items: [QuickFindItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(items) { item in
                Button {
                    item.action()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(item.iconColor)
                            .frame(width: 22, height: 22)

                        Text(item.title)
                            .font(.system(size: 15, weight: .medium))

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
