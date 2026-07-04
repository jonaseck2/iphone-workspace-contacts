// app/Sources/WorkspaceContactsApp.swift
import SwiftUI
import GoogleSignIn

@main
struct WorkspaceContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
