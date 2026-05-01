// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhatCable",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WhatCable",
            path: "Sources/WhatCable"
        ),
        .testTarget(
            name: "WhatCableTests",
            dependencies: ["WhatCable"],
            path: "Tests/WhatCableTests"
        )
    ]
)
