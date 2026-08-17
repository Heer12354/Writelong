// swift-tools-version: 5.9

import PackageDescription
import Foundation

let llamaFrameworkPath = "Vendor/llama.xcframework"
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let hasVendoredLlama = FileManager.default.fileExists(
    atPath: packageDirectory.appendingPathComponent(llamaFrameworkPath).path
)

var products: [Product] = [
    .library(name: "ModelRuntime", targets: ["ModelRuntime"])
]

var targets: [Target] = [
    .target(
        name: "ModelRuntime",
        dependencies: [
            .product(name: "AutocompleteCore", package: "AutocompleteCore")
        ]
    ),
    .testTarget(
        name: "ModelRuntimeTests",
        dependencies: [
            "ModelRuntime"
        ],
        path: "Tests/ModelRuntimeTests",
        exclude: [
            "AnchoredLogitsCorrectnessTests.swift",
            "LlamaModelRuntimeTests.swift",
            "PrefillLatencyBenchmarkTests.swift"
        ]
    )
]

if hasVendoredLlama {
    products.append(.library(name: "LlamaModelRuntime", targets: ["LlamaModelRuntime"]))
    targets += [
        // llama.cpp xcframework (see ADR-007). The framework is gitignored under Vendor/
        // and must be present locally for the LlamaModelRuntime target to build.
        .binaryTarget(
            name: "llama",
            path: llamaFrameworkPath
        ),
        .target(
            name: "LlamaModelRuntime",
            dependencies: [
                .product(name: "AutocompleteCore", package: "AutocompleteCore"),
                .product(name: "TokenProfiles", package: "TokenProfiles"),
                "ModelRuntime",
                "llama"
            ]
        ),
        .testTarget(
            name: "LlamaModelRuntimeTests",
            dependencies: [
                "ModelRuntime",
                "LlamaModelRuntime"
            ],
            path: "Tests/ModelRuntimeTests",
            exclude: ["StubModelRuntimeTests.swift"]
        )
    ]
}

let package = Package(
    name: "ModelRuntime",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: [
        .package(path: "../AutocompleteCore"),
        .package(path: "../TokenProfiles")
    ],
    targets: targets
)
