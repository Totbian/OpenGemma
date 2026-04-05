import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.opengemma", category: "ModelManager")

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
        logger.info("init — restoredModelID=\(self.selectedModelID.isEmpty ? "(none)" : self.selectedModelID)")
    }

    var selectedModel: ModelInfo? {
        availableModels.first { $0.id == selectedModelID }
    }

    var loadingProgress: Double {
        engine.loadingProgress
    }

    func selectAndLoadModel(_ model: ModelInfo) {
        guard !isLoadingModel else {
            logger.warning("selectAndLoadModel() — already loading, ignoring request for \(model.id)")
            return
        }

        logger.info("selectAndLoadModel() START — model=\(model.id), hfID=\(model.huggingFaceID), size=\(model.formattedSize)")
        selectedModelID = model.id
        isLoadingModel = true
        loadError = nil

        Task {
            do {
                try await engine.loadModel(id: model.huggingFaceID)
                logger.info("selectAndLoadModel() SUCCESS — \(model.id) loaded")
            } catch {
                logger.error("selectAndLoadModel() FAILED — \(model.id): \(error.localizedDescription)")
                loadError = error.localizedDescription
            }
            isLoadingModel = false
        }
    }

    func unloadModel() {
        logger.info("unloadModel() — was: \(self.selectedModelID)")
        engine.unloadModel()
        selectedModelID = ""
    }
}
