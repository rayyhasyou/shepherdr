// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shepherdr",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShepherdrCore", targets: ["ShepherdrCore"]),
        .executable(name: "shepherdr-probe", targets: ["ShepherdrProbe"]),
        .executable(name: "shepherdr", targets: ["ShepherdrApp"])
    ],
    targets: [
        .target(name: "ShepherdrCore"),
        .executableTarget(name: "ShepherdrProbe", dependencies: ["ShepherdrCore"]),
        .executableTarget(name: "ShepherdrApp", dependencies: ["ShepherdrCore"], path: "App"),
        .testTarget(name: "ShepherdrCoreTests", dependencies: ["ShepherdrCore"],
                    resources: [.copy("Fixtures")])
    ]
)
