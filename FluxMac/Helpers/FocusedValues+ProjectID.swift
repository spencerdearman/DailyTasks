//
//  FocusedValues+ProjectID.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - Focused Value Key

private struct SelectedProjectIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {

    /// The currently selected project ID, propagated through the focused value system.
    var selectedProjectID: UUID? {
        get { self[SelectedProjectIDKey.self] }
        set { self[SelectedProjectIDKey.self] = newValue }
    }
}
