//
//  SectionCard.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - SectionCard

/// A titled card that displays a count badge and wraps arbitrary content in a vertical stack.
struct SectionCard<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: Content

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                content
            }
        }
    }
}
