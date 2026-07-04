// app/Sources/ContentView.swift
import SwiftUI
import WorkspaceContactsCore

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Colleagues")
                .toolbar {
                    if model.authState == .signedIn {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("Sync now") { Task { await model.syncNow() } }
                                Button("Remove all synced contacts", role: .destructive) {
                                    Task { await model.removeAllSyncedContacts() }
                                }
                                Divider()
                                Button("Sign out") { Task { await model.signOut() } }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
        }
        .task { await model.restore() }
    }

    @ViewBuilder
    private var content: some View {
        switch (model.authState, model.consentGiven, model.status) {
        case (let s, _, _) where s != .signedIn:
            signInScreen
        case (.signedIn, false, _):
            consentScreen
        default:
            signedInBody
        }
    }

    private var signInScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle").font(.system(size: 56))
            Text("See your Imeto colleagues on incoming calls.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Sign in with Google") { Task { await model.signIn() } }
                .buttonStyle(.borderedProminent)
            if case .error(let msg) = model.authState {
                Text(msg).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }.padding()
    }

    private var consentScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 56))
            Text("Add colleagues to Contacts")
                .font(.headline)
            Text("To show colleague names on incoming calls and let you call them by name, "
                 + "WorkspaceContacts adds them to your device Contacts. These contacts live in "
                 + "your real address book and may sync to iCloud. You can remove them anytime with "
                 + "\u{201C}Remove all synced contacts\u{201D}, and signing out removes them.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Enable & sync") { Task { await model.enableSyncWithConsent() } }
                .buttonStyle(.borderedProminent)
            if model.syncStatus == .permissionDenied {
                Text("Contacts access is off. Enable it in Settings › WorkspaceContacts › Contacts.")
                    .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }.padding()
    }

    @ViewBuilder
    private var signedInBody: some View {
        VStack(spacing: 0) {
            syncStatusRow
            listOrStatus
        }
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        switch model.syncStatus {
        case .syncing:
            Label("Syncing to Contacts…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
        case .synced(let count, _):
            Label("\(count) colleagues synced to Contacts", systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red).padding(.vertical, 4)
        case .idle, .permissionDenied:
            EmptyView()
        }
    }

    @ViewBuilder
    private var listOrStatus: some View {
        switch model.status {
        case .loading:
            Spacer(); ProgressView("Loading directory…"); Spacer()
        case .failed(let message):
            Spacer()
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Try again") { Task { await model.syncNow(); await model.restore() } }
            }.padding()
            Spacer()
        default:
            list
        }
    }

    private var list: some View {
        List(model.people, id: \.resourceName) { person in
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName).font(.body)
                if let title = person.organizationTitle {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                if let phone = person.phoneNumbers.first {
                    Text(phone).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await model.refresh() }
    }
}
