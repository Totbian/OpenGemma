import Foundation
import SwiftData

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var isComplete: Bool
    var conversation: Conversation?

    init(role: MessageRole, content: String, isComplete: Bool = true) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.isComplete = isComplete
    }
}
