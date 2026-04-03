import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    let engine: any InferenceEngine
    let modelManagerViewModel: ModelManagerViewModel
    @State private var showingModelManager = false

    var body: some View {
        List {
            if conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Tap + to start chatting with Gemma")
                )
            }

            ForEach(conversations) { conversation in
                NavigationLink {
                    ChatView(
                        viewModel: ChatViewModel(
                            conversation: conversation,
                            engine: engine,
                            modelContext: modelContext
                        )
                    )
                } label: {
                    ConversationRow(conversation: conversation)
                }
            }
            .onDelete(perform: deleteConversations)
        }
        .navigationTitle("OpenGemma")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingModelManager = true
                } label: {
                    Label("Models", systemImage: "cpu")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createConversation()
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingModelManager) {
            ModelManagerView(viewModel: modelManagerViewModel)
        }
    }

    private func createConversation() {
        let conversation = Conversation(
            modelID: modelManagerViewModel.selectedModelID
        )
        modelContext.insert(conversation)
        try? modelContext.save()
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(conversations[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(conversation.lastMessagePreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !conversation.modelID.isEmpty {
                Text(conversation.modelID)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
