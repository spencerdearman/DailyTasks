//
//  EmptyCard.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - EmptyCard

/// A placeholder card displayed when a section has no content.
struct EmptyCard: View {
    let title: String

    // MARK: Body

    var body: some View {
        Text("Nothing in \(title.lowercased()) right now.")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}
