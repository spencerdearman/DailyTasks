import Foundation
import SwiftData

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case someday
    case completed
    
    var id: String { rawValue }
}
