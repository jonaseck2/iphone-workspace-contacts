// app/Sources/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.largeTitle)
            Text("WorkspaceContacts")
                .font(.headline)
        }
        .padding()
    }
}
