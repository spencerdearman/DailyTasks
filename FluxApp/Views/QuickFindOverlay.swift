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

    private var coreListResults: [(String, String, Color, SidebarSelection)] {
        let lists: [(String, String, Color, SidebarSelection)] = [
            ("Inbox", "tray.fill", .primary, .inbox),
            ("Today", "sun.max.fill", .yellow, .today),
            ("Upcoming", "calendar", .red, .upcoming),
            ("Open", "tray.2.fill", .blue, .anytime),
            ("Later", "moon.zzz.fill", .purple, .someday),
            ("Done", "checkmark.circle.fill", .green, .logbook),
        ]
        guard !query.isEmpty else { return lists }
        return lists.filter { $0.0.localizedCaseInsensitiveContains(query) }
    }

    private var areaResults: [Area] {
        guard !query.isEmpty else { return areas }
        return areas.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var projectResults: [Project] {
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var taskResults: [TaskItem] {
        guard !query.isEmpty else { return [] }
        return tasks.filter { !$0.isCompleted && $0.title.localizedCaseInsensitiveContains(query) }
            .prefix(10).map { $0 }
    }

    private var allEmpty: Bool {
        coreListResults.isEmpty && areaResults.isEmpty && projectResults.isEmpty && taskResults.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Quick Find", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .light))
                        .focused($isFocused)
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
                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !coreListResults.isEmpty {
                            quickFindSection("Lists", items: coreListResults.map { item in
                                (id: "list-\(item.0)", icon: item.1, color: item.2, title: item.0, subtitle: nil as String?, action: { onSelectSidebar(item.3) })
                            })
                        }
                        if !areaResults.isEmpty {
                            quickFindSection("Areas", items: areaResults.map { area in
                                (id: "area-\(area.id)", icon: area.symbolName, color: Color(hex: area.tintHex), title: area.title, subtitle: nil as String?, action: { onSelectSidebar(.area(area.id)) })
                            })
                        }
                        if !projectResults.isEmpty {
                            quickFindSection("Projects", items: projectResults.map { project in
                                (id: "project-\(project.id)", icon: "paperplane", color: Color(hex: project.tintHex), title: project.title, subtitle: project.area?.title, action: { onSelectSidebar(.project(project.id)) })
                            })
                        }
                        if !taskResults.isEmpty {
                            quickFindSection("Tasks", items: taskResults.map { task in
                                (id: "task-\(task.id)", icon: "circle", color: Color.secondary, title: task.title, subtitle: task.project?.title ?? task.area?.title, action: { onSelectTask(task) })
                            })
                        }
                        if allEmpty {
                            Text("No results")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 400)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
        }
    }

    private func quickFindSection(_ title: String, items: [(id: String, icon: String, color: Color, title: String, subtitle: String?, action: () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(items, id: \.id) { item in
                Button {
                    item.action()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(item.color)
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
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
