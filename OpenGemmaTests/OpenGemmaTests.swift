import XCTest
import SwiftData
@testable import OpenGemma

final class OpenGemmaTests: XCTestCase {

    // MARK: - Model Tests

    func testConversationCreation() {
        let conversation = Conversation(title: "Test Chat", modelID: "gemma-4-e2b")
        XCTAssertEqual(conversation.title, "Test Chat")
        XCTAssertEqual(conversation.modelID, "gemma-4-e2b")
        XCTAssertTrue(conversation.messages.isEmpty)
    }

    func testMessageCreation() {
        let message = Message(role: .user, content: "Hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertTrue(message.isComplete)
    }

    func testConversationSortedMessages() {
        let conversation = Conversation()
        let msg1 = Message(role: .user, content: "First")
        let msg2 = Message(role: .assistant, content: "Second")
        conversation.messages = [msg2, msg1]
        // sortedMessages orders by createdAt
        let sorted = conversation.sortedMessages
        XCTAssertEqual(sorted.count, 2)
    }

    func testLastMessagePreview() {
        let conversation = Conversation()
        XCTAssertEqual(conversation.lastMessagePreview, "No messages")

        let msg = Message(role: .user, content: "Hello world")
        conversation.messages.append(msg)
        XCTAssertEqual(conversation.lastMessagePreview, "Hello world")
    }

    // MARK: - ModelInfo Tests

    func testAvailableModels() {
        let models = ModelInfo.availableModels
        XCTAssertEqual(models.count, 3)
        XCTAssertEqual(models[0].id, "gemma-3-1b-it-4bit")
        XCTAssertEqual(models[1].id, "gemma-3-4b-it-4bit")
        XCTAssertEqual(models[2].id, "gemma-4-e4b-it-4bit")
    }

    func testModelFormattedSize() {
        let model = ModelInfo.availableModels[0]
        XCTAssertTrue(model.formattedSize.contains("GB"))
    }

    // MARK: - MockInferenceEngine Tests

    func testMockEngineStreamsTokens() async throws {
        let engine = MockInferenceEngine()
        let messages = [(role: "user", content: "Hello")]
        let stream = engine.generate(messages: messages, parameters: GenerationParameters())

        var output = ""
        for try await token in stream {
            output += token
        }

        XCTAssertFalse(output.isEmpty)
    }

    func testMockEngineCancellation() async throws {
        let engine = MockInferenceEngine()
        let messages = [(role: "user", content: "Tell me a long story")]
        let stream = engine.generate(messages: messages, parameters: GenerationParameters())

        var tokenCount = 0
        for try await _ in stream {
            tokenCount += 1
            if tokenCount >= 3 {
                await engine.cancel()
                break
            }
        }

        XCTAssertGreaterThanOrEqual(tokenCount, 1)
    }

    // MARK: - GenerationParameters Tests

    func testDefaultParameters() {
        let params = GenerationParameters()
        XCTAssertEqual(params.temperature, 0.7)
        XCTAssertEqual(params.topK, 40)
        XCTAssertEqual(params.topP, 0.95)
        XCTAssertEqual(params.maxTokens, 2048)
    }
}
