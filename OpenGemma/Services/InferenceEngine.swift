import Foundation

struct GenerationParameters: Sendable {
    var temperature: Float = 0.7
    var topK: Int = 40
    var topP: Float = 0.95
    var maxTokens: Int = 2048
    var repeatPenalty: Float = 1.1
}

protocol InferenceEngine: Sendable {
    func loadModel(from path: URL) async throws
    func generate(messages: [(role: String, content: String)], parameters: GenerationParameters) -> AsyncThrowingStream<String, Error>
    func cancel() async
    var isModelLoaded: Bool { get async }
}

// MARK: - Mock Implementation

actor MockInferenceEngine: InferenceEngine {
    private var loaded = false
    private var cancelled = false

    var isModelLoaded: Bool { loaded }

    func loadModel(from path: URL) async throws {
        try await Task.sleep(for: .milliseconds(500))
        loaded = true
    }

    func cancel() {
        cancelled = true
    }

    func generate(messages: [(role: String, content: String)], parameters: GenerationParameters) -> AsyncThrowingStream<String, Error> {
        cancelled = false
        let responses = Self.sampleResponses
        let maxTokens = parameters.maxTokens

        return AsyncThrowingStream { [weak self] continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                let lastMessage = messages.last?.content ?? ""
                let response = Self.pickResponse(for: lastMessage, from: responses)
                let words = response.split(separator: " ", omittingEmptySubsequences: false)

                // Simulate initial thinking delay
                try await Task.sleep(for: .milliseconds(300))

                var tokenCount = 0
                for (index, word) in words.enumerated() {
                    if await self.cancelled { break }
                    if tokenCount >= maxTokens { break }

                    let token = (index == 0 ? "" : " ") + word
                    continuation.yield(String(token))
                    tokenCount += 1

                    // Simulate variable token generation speed
                    let delay = UInt64.random(in: 20...60)
                    try await Task.sleep(for: .milliseconds(delay))
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func pickResponse(for input: String, from responses: [String]) -> String {
        let lower = input.lowercased()
        if lower.contains("hello") || lower.contains("hi") {
            return "Hello! I'm Gemma, running entirely on your device. How can I help you today?"
        }
        if lower.contains("code") || lower.contains("swift") || lower.contains("program") {
            return "Here's a simple Swift example:\n\n```swift\nfunc greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\n\nprint(greet(name: \"World\"))\n```\n\nThis defines a function that takes a name parameter and returns a greeting string. Would you like me to explain any part of it?"
        }
        if lower.contains("explain") || lower.contains("what") {
            return "That's a great question! Let me break it down for you.\n\nThe key concept here is that all processing happens locally on your device. No data is sent to any server — your conversations stay completely private.\n\nWould you like me to go into more detail on any specific aspect?"
        }
        return responses[abs(input.hashValue) % responses.count]
    }

    private static let sampleResponses = [
        "I'd be happy to help with that! Since I'm running on-device, everything stays private and works offline. What would you like to explore?",
        "That's an interesting question. Let me think about it step by step.\n\nFirst, we should consider the context. Then, we can work through the logic together.\n\nBased on my analysis, I think the best approach would be to break this into smaller pieces. Would you like me to elaborate?",
        "Great idea! Here are a few suggestions:\n\n1. Start with the basics and build up\n2. Consider edge cases early\n3. Test as you go\n4. Keep things simple\n\nWant me to dive deeper into any of these?",
        "I can definitely assist with that. Here's my take:\n\nThe most important thing to consider is the overall structure. Once that's solid, the details tend to fall into place naturally.\n\nShall I provide a more detailed breakdown?",
        "Absolutely! Let me walk you through this.\n\nThe fundamental idea is straightforward — we take the input, process it through a series of well-defined steps, and produce the desired output. The beauty of this approach is its simplicity.\n\nDo you have any follow-up questions?",
    ]
}
