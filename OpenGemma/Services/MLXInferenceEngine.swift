import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import os.log

private let logger = Logger(subsystem: "com.opengemma", category: "MLXInferenceEngine")

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
        logger.info("loadModel(id:) START — id=\(id)")
        container = nil
        loadingProgress = 0

        let config = ModelConfiguration(
            id: id,
            extraEOSTokens: ["<end_of_turn>"]
        )
        logger.debug("ModelConfiguration created — extraEOSTokens=[\"<end_of_turn>\"]")

        let loadStart = CFAbsoluteTimeGetCurrent()
        do {
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { progress in
                let frac = progress.fractionCompleted
                logger.debug("Download/load progress: \(frac, format: .fixed(precision: 2))")
                Task { @MainActor in
                    self.loadingProgress = frac
                }
            }
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
            logger.error("loadModel(id:) FAILED after \(elapsed, format: .fixed(precision: 2))s — \(error.localizedDescription)")
            throw error
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
        loadingProgress = 1.0
        logger.info("loadModel(id:) SUCCESS — loaded in \(elapsed, format: .fixed(precision: 2))s, container=\(self.container != nil)")
    }

    /// Load a model from a local directory path
    func loadModel(from path: URL) async throws {
        logger.info("loadModel(from:) START — path=\(path.path)")
        container = nil
        loadingProgress = 0

        let config = ModelConfiguration(directory: path)
        let loadStart = CFAbsoluteTimeGetCurrent()
        do {
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { progress in
                let frac = progress.fractionCompleted
                logger.debug("Local load progress: \(frac, format: .fixed(precision: 2))")
                Task { @MainActor in
                    self.loadingProgress = frac
                }
            }
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
            logger.error("loadModel(from:) FAILED after \(elapsed, format: .fixed(precision: 2))s — \(error.localizedDescription)")
            throw error
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
        loadingProgress = 1.0
        logger.info("loadModel(from:) SUCCESS — loaded in \(elapsed, format: .fixed(precision: 2))s")
    }

    func generate(
        messages: [(role: String, content: String)],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<String, Error> {
        logger.info("generate() called — \(messages.count) messages, maxTokens=\(parameters.maxTokens), temp=\(parameters.temperature), topP=\(parameters.topP), repeatPenalty=\(parameters.repeatPenalty)")
        for (i, msg) in messages.enumerated() {
            logger.debug("  message[\(i)] role=\(msg.role) contentLength=\(msg.content.count)")
        }

        return AsyncThrowingStream { continuation in
            self.generationTask = Task {
                let genStart = CFAbsoluteTimeGetCurrent()
                var tokenCount = 0

                do {
                    guard let container = self.container else {
                        logger.error("generate() FAILED — model not loaded (container is nil)")
                        continuation.finish(throwing: InferenceError.modelNotLoaded)
                        return
                    }
                    logger.debug("generate() container found, calling container.perform...")

                    try await container.perform { context in
                        let chatMessages: [Chat.Message] = messages.map {
                            Chat.Message(role: Chat.Message.Role(rawValue: $0.role) ?? .user, content: $0.content)
                        }
                        logger.debug("generate() prepared \(chatMessages.count) Chat.Messages")

                        logger.debug("generate() calling context.processor.prepare(input:)...")
                        let input = try await context.processor.prepare(
                            input: UserInput(prompt: .chat(chatMessages))
                        )
                        logger.info("generate() input prepared successfully")

                        let genParams = MLXLMCommon.GenerateParameters(
                            maxTokens: parameters.maxTokens,
                            temperature: parameters.temperature,
                            topP: parameters.topP,
                            repetitionPenalty: parameters.repeatPenalty
                        )
                        logger.debug("generate() starting MLXLMCommon.generate()...")

                        let firstTokenTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
                        var gotFirstToken = false

                        for await item in try MLXLMCommon.generate(
                            input: input,
                            parameters: genParams,
                            context: context
                        ) {
                            if Task.isCancelled {
                                logger.info("generate() cancelled after \(tokenCount) tokens")
                                continuation.finish()
                                return
                            }

                            switch item {
                            case .chunk(let text):
                                if !gotFirstToken {
                                    let ttft = CFAbsoluteTimeGetCurrent() - firstTokenTime
                                    logger.info("generate() first token received — TTFT=\(ttft, format: .fixed(precision: 3))s")
                                    gotFirstToken = true
                                }
                                tokenCount += 1
                                continuation.yield(text)
                            case .info:
                                let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                                let tps = elapsed > 0 ? Double(tokenCount) / elapsed : 0
                                logger.info("generate() COMPLETE — \(tokenCount) tokens in \(elapsed, format: .fixed(precision: 2))s (\(tps, format: .fixed(precision: 1)) tok/s)")
                                continuation.finish()
                                return
                            default:
                                logger.debug("generate() received unknown item type")
                                break
                            }
                        }

                        let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                        logger.info("generate() stream ended — \(tokenCount) tokens in \(elapsed, format: .fixed(precision: 2))s")
                        continuation.finish()
                    }
                } catch is CancellationError {
                    logger.info("generate() cancelled (CancellationError) after \(tokenCount) tokens")
                    continuation.finish()
                } catch {
                    let elapsed = CFAbsoluteTimeGetCurrent() - genStart
                    logger.error("generate() ERROR after \(elapsed, format: .fixed(precision: 2))s, \(tokenCount) tokens — \(error.localizedDescription)")
                    logger.error("generate() error type: \(String(describing: type(of: error)))")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] reason in
                logger.debug("generate() stream terminated — reason: \(String(describing: reason))")
                self?.generationTask?.cancel()
            }
        }
    }

    func cancel() async {
        logger.info("cancel() called — task exists: \(self.generationTask != nil)")
        generationTask?.cancel()
        generationTask = nil
    }

    func unloadModel() {
        logger.info("unloadModel() called")
        container = nil
        loadingProgress = 0
    }
}
