// app/Sources/WorkspaceContactsApp.swift
import SwiftUI
import GoogleSignIn
import BackgroundTasks

@main
struct WorkspaceContactsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    static let refreshTaskID = "com.imeto.workspacecontacts.app.refresh"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            await BackgroundSync.run()
            await Self.scheduleRefresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { Task { await Self.scheduleRefresh() } }
        }
    }

    /// Ask the system to run our refresh no earlier than ~6 hours from now.
    @MainActor
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
