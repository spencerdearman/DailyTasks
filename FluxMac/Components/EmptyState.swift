import SwiftData
import SwiftUI

struct EmptyState: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing in \(title.lowercased()) right now.")
                .font(.title3.weight(.semibold))
            Text("Use Quick Entry to capture something new, or drag tasks in from another project or area.")
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
