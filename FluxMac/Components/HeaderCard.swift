import SwiftData
import SwiftUI

struct HeaderCard: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}
