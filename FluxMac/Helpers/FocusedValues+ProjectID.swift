import SwiftUI

private struct SelectedProjectIDKey: FocusedValueKey {
    typealias Value = UUID
}

extension FocusedValues {
    var selectedProjectID: UUID? {
        get { self[SelectedProjectIDKey.self] }
        set { self[SelectedProjectIDKey.self] = newValue }
    }
}
