import SwiftData
import SwiftUI

struct Badge: View {
    let text: String
    let tint: String
    
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(hex: tint))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: tint).opacity(0.12), in: Capsule())
    }
}
