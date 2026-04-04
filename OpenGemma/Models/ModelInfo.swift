import Foundation

struct ModelInfo: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let parameterCount: String
    let sizeInBytes: Int64
    let huggingFaceID: String
    let minimumRAMGB: Int
    let description: String

    var formattedSize: String {
        let gb = Double(sizeInBytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "gemma-3-1b-it-4bit",
            displayName: "Gemma 3 1B",
            parameterCount: "1B",
            sizeInBytes: 733_000_000,
            huggingFaceID: "mlx-community/gemma-3-1b-it-4bit",
            minimumRAMGB: 2,
            description: "Smallest and fastest. Good for basic tasks on any iPhone."
        ),
        ModelInfo(
            id: "gemma-3-4b-it-4bit",
            displayName: "Gemma 3 4B",
            parameterCount: "4B",
            sizeInBytes: 3_400_000_000,
            huggingFaceID: "mlx-community/gemma-3-4b-it-4bit",
            minimumRAMGB: 4,
            description: "Great balance of speed and quality. Recommended for most iPhones."
        ),
        ModelInfo(
            id: "gemma-4-e4b-it-4bit",
            displayName: "Gemma 4 E4B",
            parameterCount: "4B",
            sizeInBytes: 3_500_000_000,
            huggingFaceID: "mlx-community/gemma-4-e4b-it-4bit",
            minimumRAMGB: 4,
            description: "Latest Gemma 4. Best quality for on-device chat. iPhone 15 Pro+ recommended."
        ),
    ]
}
