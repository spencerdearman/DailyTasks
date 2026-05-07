//
//  TasksCompleteView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - TasksCompleteView

/// Celebratory view shown when all visible tasks have been completed.
struct TasksCompleteView: View {

    // MARK: - Properties

    var totalTasks: Int

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ProgressView(value: 1.0)
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
                    .glassEffect()
                    .scaleEffect(1.7)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 90, height: 90)
            .padding(6)

            Text("All Done")
                .font(.headline)
                .bold()
                .foregroundColor(.white)

            Text("\(totalTasks) tasks completed")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
