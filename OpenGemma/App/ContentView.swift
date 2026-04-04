import SwiftUI

struct ContentView: View {
    let engine: any InferenceEngine
    let modelManagerViewModel: ModelManagerViewModel

    var body: some View {
        NavigationStack {
            ConversationListView(
                engine: engine,
                modelManagerViewModel: modelManagerViewModel
            )
        }
    }
}
