import SwiftUI
import SwiftData

@main
struct OpenGemmaApp: App {
    private let container: ModelContainer
    private let engine: any InferenceEngine
    @State private var downloadService = ModelDownloadService()
    @State private var modelManagerViewModel: ModelManagerViewModel

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
        let service = ModelDownloadService()
        _downloadService = State(initialValue: service)
        _modelManagerViewModel = State(initialValue: ModelManagerViewModel(downloadService: service))
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
