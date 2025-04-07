// MARK: ADDED FILE - Views/ImageList/LoadingView.swift
// File: BrickAI/Views/ImageList/LoadingView.swift
// Simple view for the initial loading state

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading Images...")
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
// MARK: END ADDED FILE - Views/ImageList/LoadingView.swift