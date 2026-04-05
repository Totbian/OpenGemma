import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.opengemma", category: "App")

@main
struct OpenGemmaApp: App {
    private let container: ModelContainer
    @State private var engine = MLXInferenceEngine()
    @State private var modelManagerViewModel: ModelManagerViewModel

    init() {
        logger.info("OpenGemmaApp init START")
        let schema = Schema([Conversation.self, Message.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            logger.info("SwiftData ModelContainer created successfully")
        } catch {
            logger.fault("Failed to create ModelContainer: \(error.localizedDescription)")
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let mlxEngine = MLXInferenceEngine()
        _engine = State(initialValue: mlxEngine)
        _modelManagerViewModel = State(initialValue: ModelManagerViewModel(engine: mlxEngine))
        logger.info("OpenGemmaApp init COMPLETE — engine and model manager ready")
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
