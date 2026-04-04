import Foundation
import MLX
import MLXLLM
import MLXLMCommon

enum InferenceError: LocalizedError {
    case modelNotLoaded
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is loaded. Please download and select a model first."
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        }
    }
}

@Observable
final class MLXInferenceEngine: InferenceEngine, @unchecked Sendable {
    private var container: ModelContainer?
    private var generationTask: Task<Void, Never>?
    private(set) var loadingProgress: Double = 0

    var isModelLoaded: Bool {
        get async { container != nil }
    }

    /// Load a model from a HuggingFace model ID (e.g. "mlx-community/gemma-3-4b-it-4bit")
    func loadModel(id: String) async throws {
        container = nil
        loadingProgress = 0

        let config = ModelConfiguration(id: id)
        container = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { progress in
            Task { @MainActor in
                self.loadingProgress = progress.fractionCompleted
            }
        }

        loadingProgress = 1.0
    }

    /// Load a model from a local directory path
    func loadModel(from path: URL) async throws {
        container = nil
        loadingProgress = 0

        let config = ModelConfiguration(directory: path)
        container = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { progress in
            Task { @MainActor in
                self.loadingProgress = progress.fractionCompleted
            }
        }

        loadingProgress = 1.0
    }

    func generate(
        messages: [(role: String, content: String)],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            generationTask = Task {
                do {
                    guard let container else {
                        continuation.finish(throwing: InferenceError.modelNotLoaded)
                        return
                    }

                    try await container.perform { context in
                        let chatMessages: [[String: String]] = messages.map {
                            ["role": $0.role, "content": $0.content]
                        }

                        let input = try await context.processor.prepare(
                            input: UserInput(prompt: .chat(chatMessages))
                        )

                        let genParams = MLXLMCommon.GenerateParameters(
                            maxTokens: parameters.maxTokens,
                            temperature: parameters.temperature,
                            topP: parameters.topP,
                            repetitionPenalty: parameters.repeatPenalty
                        )

                        for await item in try MLXLMCommon.generate(
                            input: input,
                            parameters: genParams,
                            context: context
                        ) {
                            if Task.isCancelled {
                                continuation.finish()
                                return
                            }

                            switch item {
                            case .chunk(let text):
                                continuation.yield(text)
                            case .info:
                                continuation.finish()
                                return
                            default:
                                break
                            }
                        }

                        continuation.finish()
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.generationTask?.cancel()
            }
        }
    }

    func cancel() async {
        generationTask?.cancel()
        generationTask = nil
    }

    func unloadModel() {
        container = nil
        loadingProgress = 0
    }
}
