import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelID: String

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(title: String = "New Chat", modelID: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelID = modelID
        self.messages = []
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    var lastMessagePreview: String {
        sortedMessages.last?.content.prefix(80).description ?? "No messages"
    }
}
