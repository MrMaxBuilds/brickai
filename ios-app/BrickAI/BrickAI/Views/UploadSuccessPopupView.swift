// MARK: NEW FILE - Views/Notifications/UploadSuccessPopupView.swift
// File: BrickAI/Views/Notifications/UploadSuccessPopupView.swift
// An enhanced popup view to indicate successful image upload.

import SwiftUI

struct UploadSuccessPopupView: View {
    // State for entry animation
    @State private var scaleEffect: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title) // Slightly larger icon
                .foregroundColor(.white)
            Text("Image Uploaded!") // More exciting text
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        // Use a vibrant green gradient background
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule()) // Use Capsule shape
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4) // Enhanced shadow
        // Apply scaling and opacity based on state for entry animation
        .scaleEffect(scaleEffect)
        .opacity(opacity)
        // Animation triggered on appear
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                scaleEffect = 1.0 // Scale up
                opacity = 1.0   // Fade in
            }
        }
    }
}

// Preview for UploadSuccessPopupView
struct UploadSuccessPopupView_Previews: PreviewProvider {
    static var previews: some View {
        UploadSuccessPopupView()
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color.gray) // Add background for contrast
    }
}
// MARK: END NEW FILE - Views/Notifications/UploadSuccessPopupView.swift