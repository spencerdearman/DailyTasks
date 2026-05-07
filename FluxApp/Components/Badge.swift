//
//  Badge.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - Badge

/// A small capsule-shaped label tinted with the given hex color.
struct Badge: View {
    let text: String
    let tint: String

    // MARK: Body

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(hex: tint))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: tint).opacity(0.12), in: Capsule())
    }
}
