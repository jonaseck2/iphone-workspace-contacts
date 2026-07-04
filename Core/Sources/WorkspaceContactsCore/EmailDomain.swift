// Core/Sources/WorkspaceContactsCore/EmailDomain.swift
import Foundation

/// Pure helper for verifying an email belongs to a specific domain.
/// Used to enforce single-org (imeto.com) sign-in on the client side.
public enum EmailDomain {
    /// True only when `email` has exactly one `@` and the domain part equals `domain`
    /// (case-insensitively, ignoring surrounding whitespace).
    public static func matches(email: String, domain: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1].lowercased() == domain.lowercased()
    }
}
