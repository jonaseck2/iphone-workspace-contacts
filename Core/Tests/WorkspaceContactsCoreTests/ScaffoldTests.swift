// Core/Tests/WorkspaceContactsCoreTests/ScaffoldTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct ScaffoldTests {
    @Test func packageVersionIsSet() {
        #expect(WorkspaceContactsCore.version == "0.1.0")
    }
}
