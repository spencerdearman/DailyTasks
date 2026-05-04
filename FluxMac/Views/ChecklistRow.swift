import SwiftData
import SwiftUI

struct ChecklistRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ChecklistItem
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                item.isCompleted.toggle()
                try? modelContext.save()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(item.isCompleted ? Color.green : Color.gray.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
                
                Text(item.title)
                    .font(.subheadline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}
