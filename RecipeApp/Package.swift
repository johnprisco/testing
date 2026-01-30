// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecipeApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "RecipeExtraction",
            targets: ["RecipeExtraction"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "RecipeExtraction",
            dependencies: ["SwiftSoup"],
            path: "RecipeApp/Services"
        ),
        .testTarget(
            name: "RecipeExtractionTests",
            dependencies: ["RecipeExtraction"],
            path: "RecipeAppTests"
        ),
    ]
)
