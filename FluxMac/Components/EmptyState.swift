//
//  EmptyState.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - EmptyState

/// A placeholder view shown when a list section has no items.
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
