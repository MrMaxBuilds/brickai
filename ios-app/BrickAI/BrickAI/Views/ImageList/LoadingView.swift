// MARK: ADDED FILE - Views/ImageList/LoadingView.swift
// File: BrickAI/Views/ImageList/LoadingView.swift
// Simple view for the initial loading state

import SwiftUI

struct LoadingView: View {
    var body: some View {
// <-----CHANGE START------>
        ProgressView {
            Text("Loading Images...")
                .foregroundColor(.white)
        }
        .progressViewStyle(CircularProgressViewStyle(tint: .white))
// <-----CHANGE END-------->
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
// <-----CHANGE START------>
            .background(Color.black)
// <-----CHANGE END-------->
    }
}
// MARK: END ADDED FILE - Views/ImageList/LoadingView.swift