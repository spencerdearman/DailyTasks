//
//  DateBadge.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - DateBadge

/// A compact date label that adjusts its visual emphasis based on whether it's a deadline.
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
