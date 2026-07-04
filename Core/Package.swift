// swift-tools-version:5.9
import PackageDescription
import Foundation

// swift-testing runtime wiring for Command Line Tools:
// The CLT toolchain ships the swift-testing *module interface* but not on the default
// runtime search path, so a bare `swift test` links fine yet dies at load with
// "Library not loaded: @rpath/Testing.framework/...". The SIP-protected test helper
// strips DYLD_*, so env vars can't fix it. Instead, when the CLT swift-testing
// frameworks are present, add them as a framework search path and bake their locations
// into the test bundle's @rpath. On full Xcode these paths are absent → nothing added,
// so the manifest stays portable.
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltInteropDir = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

var testSwiftSettings: [SwiftSetting] = []
var testLinkerSettings: [LinkerSetting] = []
if FileManager.default.fileExists(atPath: cltFrameworks + "/Testing.framework") {
    testSwiftSettings.append(.unsafeFlags(["-F", cltFrameworks]))
    testLinkerSettings.append(.unsafeFlags([
        "-F", cltFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", cltFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", cltInteropDir,
    ]))
}

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
            dependencies: ["WorkspaceContactsCore"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
