// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PromptManagerApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PromptManagerApp",
            targets: ["PromptManagerApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PromptManagerApp",
            path: "Sources/PromptManagerApp"
        )
    ]
)
