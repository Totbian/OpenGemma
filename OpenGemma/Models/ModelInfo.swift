import Foundation

struct ModelInfo: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let parameterCount: String
    let sizeInBytes: Int64
    let downloadURL: URL
    let minimumRAMGB: Int
    let description: String

    var formattedSize: String {
        let gb = Double(sizeInBytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "gemma-4-e2b",
            displayName: "Gemma 4 E2B",
            parameterCount: "2B",
            sizeInBytes: 2_770_743_091,
            downloadURL: URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-litert-lm-multi.bin")!,
            minimumRAMGB: 4,
            description: "Fast and lightweight. Great for quick responses on any modern iPhone."
        ),
        ModelInfo(
            id: "gemma-4-e4b",
            displayName: "Gemma 4 E4B",
            parameterCount: "4B",
            sizeInBytes: 3_921_068_851,
            downloadURL: URL(string: "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it-litert-lm-multi.bin")!,
            minimumRAMGB: 6,
            description: "More capable. Best on iPhone 15 Pro or newer."
        ),
    ]
}
