// Core/Tests/WorkspaceContactsCoreTests/EmailDomainTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct EmailDomainTests {
    @Test func matchesExactDomain() {
        #expect(EmailDomain.matches(email: "jane@imeto.com", domain: "imeto.com"))
    }

    @Test func isCaseInsensitive() {
        #expect(EmailDomain.matches(email: "Jane@IMETO.com", domain: "imeto.com"))
        #expect(EmailDomain.matches(email: "jane@imeto.com", domain: "IMETO.COM"))
    }

    @Test func trimsWhitespace() {
        #expect(EmailDomain.matches(email: "  jane@imeto.com  ", domain: "imeto.com"))
    }

    @Test func rejectsOtherDomain() {
        #expect(!EmailDomain.matches(email: "jane@gmail.com", domain: "imeto.com"))
    }

    @Test func rejectsSubdomainImpersonation() {
        // "imeto.com.evil.com" must NOT match "imeto.com"
        #expect(!EmailDomain.matches(email: "jane@imeto.com.evil.com", domain: "imeto.com"))
        // "notimeto.com" must NOT match
        #expect(!EmailDomain.matches(email: "jane@notimeto.com", domain: "imeto.com"))
    }

    @Test func rejectsMalformed() {
        #expect(!EmailDomain.matches(email: "jane", domain: "imeto.com"))
        #expect(!EmailDomain.matches(email: "jane@a@imeto.com", domain: "imeto.com"))
        #expect(!EmailDomain.matches(email: "", domain: "imeto.com"))
    }
}
