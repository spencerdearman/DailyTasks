import SwiftData
import SwiftUI

struct QuickFindOverlay: View {
    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let onSelectSidebar: (SidebarSelection) -> Void
    let onSelectTask: (TaskItem) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool
    @State private var selectedIndex = 0

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

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Spotlight-style search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Quick Find", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .light))
                        .focused($isFocused)
                        .onSubmit {
                            if let item = allItems[safe: selectedIndex] {
                                item.action()
                            }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                if !allItems.isEmpty || !query.isEmpty {
                    Divider()
                        .padding(.horizontal, 12)

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
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 340)
                }
            }
            .frame(width: 540)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 40, y: 12)
            .padding(.bottom, 120)
        }
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, allItems.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
    }

    private func quickFindSection(_ title: String, items: [QuickFindItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let globalIndex = globalIndex(for: item)
                Button {
                    item.action()
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.iconColor)
                            .frame(width: 24, height: 24)
                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        globalIndex == selectedIndex
                        ? Color.accentColor.opacity(0.12)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
    }

    private func globalIndex(for item: QuickFindItem) -> Int {
        allItems.firstIndex(where: { $0.id == item.id }) ?? -1
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
