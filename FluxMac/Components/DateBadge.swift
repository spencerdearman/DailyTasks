import SwiftData
import SwiftUI

struct DateBadge: View {
    let date: Date
    let isDeadline: Bool
    
    var body: some View {
        Text(date.formatted(.dateTime.month(.abbreviated).day()))
            .font(.caption.weight(.medium))
            .foregroundStyle(isDeadline ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(isDeadline ? 0.10 : 0.06), in: Capsule())
    }
}
