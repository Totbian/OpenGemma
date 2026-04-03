import Foundation

@Observable
final class ModelDownloadService: NSObject {
    var downloadProgress: [String: Double] = [:]
    var downloadedModelPaths: [String: URL] = [:]
    var activeDownloads: Set<String> = []
    var errorMessages: [String: String] = [:]

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private static let downloadedModelsKey = "downloadedModelPaths"

    override init() {
        super.init()
        loadPersistedPaths()
    }

    // MARK: - Public API

    func isDownloaded(_ model: ModelInfo) -> Bool {
        guard let path = downloadedModelPaths[model.id] else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    func isDownloading(_ model: ModelInfo) -> Bool {
        activeDownloads.contains(model.id)
    }

    func progress(for model: ModelInfo) -> Double {
        downloadProgress[model.id] ?? 0
    }

    func download(_ model: ModelInfo) {
        guard !isDownloading(model) else { return }

        errorMessages[model.id] = nil
        activeDownloads.insert(model.id)
        downloadProgress[model.id] = 0

        let task: URLSessionDownloadTask
        if let data = resumeData[model.id] {
            task = session.downloadTask(withResumeData: data)
            resumeData[model.id] = nil
        } else {
            task = session.downloadTask(with: model.downloadURL)
        }

        task.taskDescription = model.id
        downloadTasks[model.id] = task
        task.resume()
    }

    func pause(_ model: ModelInfo) {
        guard let task = downloadTasks[model.id] else { return }
        task.cancel { [weak self] data in
            DispatchQueue.main.async {
                self?.resumeData[model.id] = data
                self?.activeDownloads.remove(model.id)
                self?.downloadTasks[model.id] = nil
            }
        }
    }

    func cancelDownload(_ model: ModelInfo) {
        downloadTasks[model.id]?.cancel()
        downloadTasks[model.id] = nil
        resumeData[model.id] = nil
        activeDownloads.remove(model.id)
        downloadProgress[model.id] = nil
        errorMessages[model.id] = nil
    }

    func deleteModel(_ model: ModelInfo) {
        cancelDownload(model)
        if let path = downloadedModelPaths[model.id] {
            try? FileManager.default.removeItem(at: path)
        }
        downloadedModelPaths[model.id] = nil
        downloadProgress[model.id] = nil
        persistPaths()
    }

    func localPath(for model: ModelInfo) -> URL? {
        guard let path = downloadedModelPaths[model.id],
              FileManager.default.fileExists(atPath: path.path) else { return nil }
        return path
    }

    // MARK: - Persistence

    private func persistPaths() {
        let dict = downloadedModelPaths.mapValues { $0.path }
        UserDefaults.standard.set(dict, forKey: Self.downloadedModelsKey)
    }

    private func loadPersistedPaths() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.downloadedModelsKey) as? [String: String] else { return }
        downloadedModelPaths = dict.compactMapValues { URL(fileURLWithPath: $0) }
        // Clean up entries where files no longer exist
        for (id, url) in downloadedModelPaths {
            if !FileManager.default.fileExists(atPath: url.path) {
                downloadedModelPaths[id] = nil
            }
        }
        persistPaths()
    }

    private func modelsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelID = downloadTask.taskDescription else { return }

        let destination = modelsDirectory().appendingPathComponent("\(modelID).bin")
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDest = destination
            try mutableDest.setResourceValues(resourceValues)

            DispatchQueue.main.async { [weak self] in
                self?.downloadedModelPaths[modelID] = destination
                self?.activeDownloads.remove(modelID)
                self?.downloadTasks[modelID] = nil
                self?.downloadProgress[modelID] = 1.0
                self?.persistPaths()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessages[modelID] = "Failed to save model: \(error.localizedDescription)"
                self?.activeDownloads.remove(modelID)
                self?.downloadTasks[modelID] = nil
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let modelID = downloadTask.taskDescription else { return }
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        DispatchQueue.main.async { [weak self] in
            self?.downloadProgress[modelID] = progress
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let modelID = task.taskDescription, let error = error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }

        DispatchQueue.main.async { [weak self] in
            self?.errorMessages[modelID] = error.localizedDescription
            self?.activeDownloads.remove(modelID)
            self?.downloadTasks[modelID] = nil
        }
    }
}
