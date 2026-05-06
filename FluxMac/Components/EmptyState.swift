import SwiftData
import SwiftUI

struct EmptyState: View {
    let title: String

    var body: some View {
        Text("Nothing in \(title.lowercased()) right now.")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}
