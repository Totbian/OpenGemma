// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OpenGemma",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "OpenGemma", targets: ["OpenGemma"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "2.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", branch: "main"),
    ],
    targets: [
        .target(
            name: "OpenGemma",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "OpenGemma"
        ),
        .testTarget(
            name: "OpenGemmaTests",
            dependencies: ["OpenGemma"],
            path: "OpenGemmaTests"
        ),
    ]
)
