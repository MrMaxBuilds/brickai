// MARK: ADDED FILE - Views/ImageList/EmptyListView.swift
// File: BrickAI/Views/ImageList/EmptyListView.swift
// Simple view for the empty list state (no images uploaded yet)

import SwiftUI

struct EmptyListView: View {
    var body: some View {
        Text("You haven't uploaded any images yet.")
            .font(.title3) // Slightly larger text
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
            .multilineTextAlignment(.center)
            .padding()
    }
}

struct EmptyListView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyListView()
    }
}
// MARK: END ADDED FILE - Views/ImageList/EmptyListView.swift