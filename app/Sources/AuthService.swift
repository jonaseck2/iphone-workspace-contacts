// app/Sources/AuthService.swift
import Foundation
import GoogleSignIn
import WorkspaceContactsCore

enum AuthState: Equatable {
    case signedOut
    case signedIn
    case error(String)
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var state: AuthState = .signedOut

    private let allowedDomain = "imeto.com"
    private let directoryScope = "https://www.googleapis.com/auth/directory.readonly"

    /// Interactive sign-in. Requests the directory scope up front, then enforces the domain.
    func signIn() async {
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: RootViewController.topMost(),
                hint: nil,
                additionalScopes: [directoryScope]
            )
            try accept(result.user)
        } catch let authError as AuthError {
            state = .error(authError.message)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Silent restore on launch (also refreshes expired tokens).
    func restore() async {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try accept(user)
        } catch {
            state = .signedOut
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        email = nil
        state = .signedOut
    }

    /// A fresh access token for API calls, refreshing if needed. Nil if not signed in.
    func accessToken() async -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        if let refreshed = try? await user.refreshTokensIfNeeded() {
            return refreshed.accessToken.tokenString
        }
        return user.accessToken.tokenString
    }

    // MARK: - Private

    private func accept(_ user: GIDGoogleUser) throws {
        guard let addr = user.profile?.email,
              EmailDomain.matches(email: addr, domain: allowedDomain) else {
            GIDSignIn.sharedInstance.signOut()
            throw AuthError.wrongDomain(allowedDomain)
        }
        guard (user.grantedScopes ?? []).contains(directoryScope) else {
            GIDSignIn.sharedInstance.signOut()
            throw AuthError.missingScope
        }
        email = addr
        state = .signedIn
    }

    private enum AuthError: Error {
        case wrongDomain(String)
        case missingScope

        var message: String {
            switch self {
            case .wrongDomain(let d): return "Please sign in with your @\(d) account."
            case .missingScope: return "Directory access is required to show colleagues."
            }
        }
    }
}
