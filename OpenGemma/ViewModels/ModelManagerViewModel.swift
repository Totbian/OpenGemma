import Foundation
import SwiftUI

@Observable
@MainActor
final class ModelManagerViewModel {
    let downloadService: ModelDownloadService
    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    var availableModels: [ModelInfo] { ModelInfo.availableModels }

    init(downloadService: ModelDownloadService) {
        self.downloadService = downloadService
        self.selectedModelID = UserDefaults.standard.string(forKey: "selectedModelID") ?? ""
    }

    var selectedModel: ModelInfo? {
        availableModels.first { $0.id == selectedModelID }
    }

    var downloadedModels: [ModelInfo] {
        availableModels.filter { downloadService.isDownloaded($0) }
    }

    func isDownloaded(_ model: ModelInfo) -> Bool {
        downloadService.isDownloaded(model)
    }

    func isDownloading(_ model: ModelInfo) -> Bool {
        downloadService.isDownloading(model)
    }

    func progress(for model: ModelInfo) -> Double {
        downloadService.progress(for: model)
    }

    func errorMessage(for model: ModelInfo) -> String? {
        downloadService.errorMessages[model.id]
    }

    func download(_ model: ModelInfo) {
        downloadService.download(model)
    }

    func pause(_ model: ModelInfo) {
        downloadService.pause(model)
    }

    func cancelDownload(_ model: ModelInfo) {
        downloadService.cancelDownload(model)
    }

    func deleteModel(_ model: ModelInfo) {
        downloadService.deleteModel(model)
        if selectedModelID == model.id {
            selectedModelID = downloadedModels.first?.id ?? ""
        }
    }

    func selectModel(_ model: ModelInfo) {
        guard isDownloaded(model) else { return }
        selectedModelID = model.id
    }
}
