// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkspaceContactsCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "WorkspaceContactsCore", targets: ["WorkspaceContactsCore"]),
    ],
    targets: [
        .target(name: "WorkspaceContactsCore"),
        .testTarget(
            name: "WorkspaceContactsCoreTests",
            dependencies: ["WorkspaceContactsCore"]
        ),
    ]
)
