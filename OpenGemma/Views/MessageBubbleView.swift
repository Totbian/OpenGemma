import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Gemma")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(messageContent)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
    }

    private var messageContent: AttributedString {
        // Render basic markdown if possible, fall back to plain text
        if let attributed = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(message.content)
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            #if os(iOS)
            return Color(.systemGray5)
            #else
            return Color.gray.opacity(0.2)
            #endif
        case .system:
            #if os(iOS)
            return Color(.systemGray6)
            #else
            return Color.gray.opacity(0.15)
            #endif
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: Message(role: .user, content: "Hello, how are you?"),
            isStreaming: false
        )
        MessageBubbleView(
            message: Message(role: .assistant, content: "I'm doing great! How can I help you today?"),
            isStreaming: false
        )
    }
}
