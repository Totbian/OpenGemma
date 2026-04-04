import Foundation
import SwiftUI

@Observable
@MainActor
final class ModelManagerViewModel {
    let engine: MLXInferenceEngine
    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }
    var isLoadingModel = false
    var loadError: String?

    var availableModels: [ModelInfo] { ModelInfo.availableModels }

    init(engine: MLXInferenceEngine) {
        self.engine = engine
        self.selectedModelID = UserDefaults.standard.string(forKey: "selectedModelID") ?? ""
    }

    var selectedModel: ModelInfo? {
        availableModels.first { $0.id == selectedModelID }
    }

    var loadingProgress: Double {
        engine.loadingProgress
    }

    func selectAndLoadModel(_ model: ModelInfo) {
        guard !isLoadingModel else { return }

        selectedModelID = model.id
        isLoadingModel = true
        loadError = nil

        Task {
            do {
                try await engine.loadModel(id: model.huggingFaceID)
            } catch {
                loadError = error.localizedDescription
            }
            isLoadingModel = false
        }
    }

    func unloadModel() {
        engine.unloadModel()
        selectedModelID = ""
    }
}
