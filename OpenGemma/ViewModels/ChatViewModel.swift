import Foundation
import SwiftData
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.opengemma", category: "ChatViewModel")

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
        logger.info("init — conversation=\(conversation.id), modelID=\(conversation.modelID), engine=\(String(describing: type(of: engine)))")
    }

    var messages: [Message] {
        conversation.sortedMessages
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            logger.debug("sendMessage() — empty input, ignoring")
            return
        }

        logger.info("sendMessage() START — textLength=\(text.count), conversation=\(self.conversation.id)")

        inputText = ""
        errorMessage = nil

        let userMessage = Message(role: .user, content: text)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        logger.debug("sendMessage() — user message added, id=\(userMessage.id)")

        // Auto-title from first user message
        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(text.prefix(50))
            logger.debug("sendMessage() — auto-titled conversation: \(self.conversation.title)")
        }

        let assistantMessage = Message(role: .assistant, content: "", isComplete: false)
        conversation.messages.append(assistantMessage)
        trySave()
        logger.debug("sendMessage() — assistant placeholder added, id=\(assistantMessage.id)")

        isGenerating = true

        generateTask = Task {
            let genStart = CFAbsoluteTimeGetCurrent()
            do {
                let chatMessages = conversation.sortedMessages
                    .filter { $0.role != .system && $0.isComplete }
                    .map { (role: $0.role.rawValue, content: $0.content) }

                logger.info("sendMessage() — sending \(chatMessages.count) messages to engine")
                for (i, msg) in chatMessages.enumerated() {
                    logger.debug("  chatMsg[\(i)] role=\(msg.role) len=\(msg.content.count)")
                }

                let stream = engine.generate(
                    messages: chatMessages,
                    parameters: GenerationParameters()
                )
                logger.debug("sendMessage() — stream created, starting iteration...")

                var tokenCount = 0
                for try await token in stream {
                    assistantMessage.content += token
                    tokenCount += 1
                    if tokenCount == 1 {
                        logger.info("sendMessage() — first token received")
                    }
                    if tokenCount % 50 == 0 {
                        logger.debug("sendMessage() — \(tokenCount) tokens received so far")
                    }
                }

                let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                logger.info("sendMessage() COMPLETE — \(tokenCount) tokens in \(elapsed, format: .fixed(precision: 2))s, responseLength=\(assistantMessage.content.count)")
                assistantMessage.isComplete = true
            } catch is CancellationError {
                let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                logger.info("sendMessage() CANCELLED after \(elapsed, format: .fixed(precision: 2))s")
                assistantMessage.isComplete = true
            } catch {
                let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                logger.error("sendMessage() ERROR after \(elapsed, format: .fixed(precision: 2))s — \(error.localizedDescription)")
                logger.error("sendMessage() error type: \(String(describing: type(of: error)))")
                errorMessage = error.localizedDescription
                assistantMessage.isComplete = true
            }

            isGenerating = false
            conversation.updatedAt = Date()
            trySave()
            logger.debug("sendMessage() — state reset, isGenerating=false")
        }
    }

    func stopGenerating() {
        logger.info("stopGenerating() called")
        generateTask?.cancel()
        generateTask = nil
        Task { await engine.cancel() }
    }

    func deleteMessage(_ message: Message) {
        logger.info("deleteMessage() — id=\(message.id), role=\(message.role.rawValue)")
        conversation.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        trySave()
    }

    private func trySave() {
        do {
            try modelContext.save()
            logger.debug("trySave() — success")
        } catch {
            logger.error("trySave() FAILED — \(error.localizedDescription)")
        }
    }
}
