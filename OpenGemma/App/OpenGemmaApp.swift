import SwiftUI
import SwiftData

@main
struct OpenGemmaApp: App {
    private let container: ModelContainer
    @State private var engine = MLXInferenceEngine()
    @State private var modelManagerViewModel: ModelManagerViewModel

    init() {
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let mlxEngine = MLXInferenceEngine()
        _engine = State(initialValue: mlxEngine)
        _modelManagerViewModel = State(initialValue: ModelManagerViewModel(engine: mlxEngine))
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
