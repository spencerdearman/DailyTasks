//
//  Badge.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - Badge

/// A compact pill-shaped label with optional icon, used for metadata display.
struct Badge: View {
    let text: String
    let tint: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: tint))
            }
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: tint))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: tint).opacity(0.12), in: Capsule())
    }
}
