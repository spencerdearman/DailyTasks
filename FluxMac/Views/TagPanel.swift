import SwiftData
import SwiftUI

struct TagPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.title) private var allTags: [Tag]
    let task: TaskItem
    
    @State private var searchText = ""
    
    private var filteredTags: [Tag] {
        let unassigned = allTags.filter { tag in
            !task.tagList.contains(where: { $0.id == tag.id })
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
                    .onSubmit {
                        createTag()
                    }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            if !filteredTags.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTags.prefix(6)) { tag in
                        Button {
                            let assignment = TaskTagAssignment(task: task, tag: tag)
                            modelContext.insert(assignment)
                            task.updatedAt = .now
                            try? modelContext.save()
                            searchText = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: tag.tintHex))
                                Text(tag.title)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
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
        let assignment = TaskTagAssignment(task: task, tag: tag)
        modelContext.insert(assignment)
        task.updatedAt = .now
        try? modelContext.save()
        searchText = ""
    }
}
