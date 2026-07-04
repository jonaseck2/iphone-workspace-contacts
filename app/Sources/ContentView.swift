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
                            Button("Sign out") { model.signOut() }
                        }
                    }
                }
        }
        .task { await model.restore() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .idle where model.authState != .signedIn:
            signInScreen
        case .loading:
            ProgressView("Loading directory…")
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Try again") { Task { await model.refresh() } }
            }.padding()
        default:
            list
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
