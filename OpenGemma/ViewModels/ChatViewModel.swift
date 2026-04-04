import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    var conversation: Conversation
    var inputText = ""
    var isGenerating = false
    var errorMessage: String?

    private let engine: any InferenceEngine
    private let modelContext: ModelContext
    private var generateTask: Task<Void, Never>?

    init(conversation: Conversation, engine: any InferenceEngine, modelContext: ModelContext) {
        self.conversation = conversation
        self.engine = engine
        self.modelContext = modelContext
    }

    var messages: [Message] {
        conversation.sortedMessages
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = Message(role: .user, content: text)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()

        // Auto-title from first user message
        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(text.prefix(50))
        }

        let assistantMessage = Message(role: .assistant, content: "", isComplete: false)
        conversation.messages.append(assistantMessage)
        trySave()

        isGenerating = true

        generateTask = Task {
            do {
                let chatMessages = conversation.sortedMessages
                    .filter { $0.role != .system && $0.isComplete }
                    .map { (role: $0.role.rawValue, content: $0.content) }

                let stream = engine.generate(
                    messages: chatMessages,
                    parameters: GenerationParameters()
                )

                for try await token in stream {
                    assistantMessage.content += token
                }

                assistantMessage.isComplete = true
            } catch is CancellationError {
                assistantMessage.isComplete = true
            } catch {
                errorMessage = error.localizedDescription
                assistantMessage.isComplete = true
            }

            isGenerating = false
            conversation.updatedAt = Date()
            trySave()
        }
    }

    func stopGenerating() {
        generateTask?.cancel()
        generateTask = nil
        Task { await engine.cancel() }
    }

    func deleteMessage(_ message: Message) {
        conversation.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        trySave()
    }

    private func trySave() {
        try? modelContext.save()
    }
}
