---
name: swift-testing-headless
description: >
  Use when writing or running Swift package tests in this environment (or any Mac with only
  Command Line Tools, no full Xcode), or when `swift test` fails with "no such module
  'XCTest'". Triggers on "swift test", "XCTest", "swift-testing", "@Test", "run the Swift
  tests", "test the Core package". Explains why XCTest is unavailable and gives the working
  swift-testing pattern.
---

# Swift package testing under Command Line Tools (no Xcode)

Verified 2026-07 in this repo's environment. **Updated 2026-07 for the Swift 6.3 / Xcode 26
CLT toolchain** — bare `swift test` no longer runs swift-testing tests here; see "The run
problem" below. In this repo, just run **`make test`** in `Core/` (encapsulates the fix).

## The constraint

The CLI/agent environment has **Command Line Tools only**
(`xcode-select -p` → `/Library/Developer/CommandLineTools`). **XCTest ships only with full
Xcode**, so `import XCTest` fails with *"no such module 'XCTest'"* and any XCTest-based
`swift test` cannot build.

## The fix: use swift-testing

`swift-testing` (the `Testing` module) ships with the Swift 6.1 toolchain and **runs
headlessly via `swift test` under Command Line Tools**. It also works in full Xcode 16+, so
it's forward-compatible with a developer's local setup. **Write all package tests with
swift-testing, never XCTest.**

```swift
import Testing
@testable import MyModule

@Suite struct MyThingTests {
    @Test func doesTheThing() {
        #expect(MyThing.value == 42)
    }

    @Test func asyncWorks() async throws {
        let r = try await MyThing.fetch()
        #expect(r.count == 2)
    }
}
```

Translation from XCTest: `XCTAssertEqual(a, b)` → `#expect(a == b)`; `XCTAssertNil(x)` →
`#expect(x == nil)`; `XCTAssertTrue(x)` → `#expect(x)`; `XCTAssertThrowsError` →
`#expect(throws:) { ... }`. Test classes become `@Suite struct`; `func test_x()` become
`@Test func x()`.

## Required: declare a macOS platform floor

Without a macOS platform minimum, swift-testing macros fail with
*"'Actor' is only available in macOS 10.15 or newer"*. In `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyPackage",
    platforms: [.iOS(.v16), .macOS(.v13)],   // .macOS floor is REQUIRED for swift-testing
    targets: [
        .target(name: "MyPackage"),
        .testTarget(name: "MyPackageTests", dependencies: ["MyPackage"]),
    ]
)
```

No extra package dependency is needed — SwiftPM links `Testing` automatically.

## The run problem (Swift 6.3 / Xcode 26 CLT) and the fix

On this toolchain the CLT ships the swift-testing **module interface** but not on the default
runtime search path, and there are two distinct failures:

1. **Load failure** — a built test bundle dies with
   `Library not loaded: @rpath/Testing.framework/...` (then `@rpath/lib_TestingInterop.dylib`).
   The swift-testing runner runs under a **SIP-protected helper that strips `DYLD_*`**, so
   `DYLD_FRAMEWORK_PATH` can't fix it.
2. **Run-phase skip** — even once it loads, a **bare `swift test` runs zero tests and exits 0**.
   SwiftPM decides whether to run its swift-testing phase by probing for the module via a
   **command-line** search flag; a manifest `swiftSettings` `-F` compiles fine but doesn't flip
   that decision. Passing `-Xswiftc -F <clt-frameworks>` on the command line does.

**Fix, split across two places (both already applied in `Core/`):**

- **`Package.swift`** solves the load failure by baking the CLT frameworks dir into the test
  target's framework search path *and* `@rpath` (guarded by a `FileManager` existence check so
  it's a no-op on full Xcode):

  ```swift
  import Foundation
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
  // ...testTarget(..., swiftSettings: testSwiftSettings, linkerSettings: testLinkerSettings)
  ```
  Note `-rpath` must be passed as `-Xlinker -rpath -Xlinker <path>`; a bare `-rpath` in
  `unsafeFlags` errors with `unknown argument: '-rpath'`.

- **`Core/Makefile`** solves the run-phase skip by passing the command-line trigger:
  `swift test -Xswiftc -F -Xswiftc <clt-frameworks>`. No framework copying needed.

## Run

```bash
cd Core && make test                       # all tests (uses the fix)
cd Core && make test FILTER=MyThingTests   # one suite
```

Passing output ends with: `✔ Test run with N tests passed`.

(If a full Xcode is installed but `xcode-select` points at CLT, you *could* switch with
`sudo xcode-select -s /Applications/Xcode.app` + `sudo xcodebuild -license accept` — but that's
a sudo/license action for the developer to take, and `make test` avoids needing it.)

## Note on the app target

This covers **SwiftPM packages** (headless). An **iOS app target** still needs full Xcode to
build/run (no `xcodebuild`/Simulator under CLT) — keep pure logic in a package so it stays
headless-testable, and verify the app on a Mac with Xcode. Related: [[swift-testing-not-xctest]].
