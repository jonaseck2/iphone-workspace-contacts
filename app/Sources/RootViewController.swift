// app/Sources/RootViewController.swift
import UIKit

/// Finds the top-most view controller to present the Google sign-in sheet from,
/// which SwiftUI does not expose directly.
@MainActor
enum RootViewController {
    static func topMost() -> UIViewController {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIViewController()
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
