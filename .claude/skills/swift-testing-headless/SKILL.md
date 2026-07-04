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

Verified 2026-07 in this repo's environment.

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

## Run

```bash
cd <package-dir> && swift test              # all tests
cd <package-dir> && swift test --filter MyThingTests   # one suite
```

Passing output ends with: `✔ Test run with N tests passed`.

## Note on the app target

This covers **SwiftPM packages** (headless). An **iOS app target** still needs full Xcode to
build/run (no `xcodebuild`/Simulator under CLT) — keep pure logic in a package so it stays
headless-testable, and verify the app on a Mac with Xcode. Related: [[swift-testing-not-xctest]].
