//
//  HeaderCard.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - HeaderCard

/// A prominent title card rendered on a thin-material background with rounded corners.
struct HeaderCard: View {
    let title: String

    // MARK: Body

    var body: some View {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
