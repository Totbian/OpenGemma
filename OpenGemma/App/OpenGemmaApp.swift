import SwiftUI
import SwiftData

@main
struct OpenGemmaApp: App {
    private let container: ModelContainer
    private let engine: any InferenceEngine
    private let downloadService: ModelDownloadService
    private let modelManagerViewModel: ModelManagerViewModel

    init() {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Use mock engine for now — swap to real runtime later
        engine = MockInferenceEngine()
        downloadService = ModelDownloadService()
        modelManagerViewModel = ModelManagerViewModel(downloadService: downloadService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                engine: engine,
                modelManagerViewModel: modelManagerViewModel
            )
        }
        .modelContainer(container)
    }
}
