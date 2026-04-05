// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PromptManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PromptManager",
            targets: ["PromptManager"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PromptManager",
            path: "Sources/PromptManager"
        )
    ]
)
