// Core/Tests/WorkspaceContactsCoreTests/ScaffoldTests.swift
import XCTest
@testable import WorkspaceContactsCore

final class ScaffoldTests: XCTestCase {
    func test_packageVersionIsSet() {
        XCTAssertEqual(WorkspaceContactsCore.version, "0.1.0")
    }
}
