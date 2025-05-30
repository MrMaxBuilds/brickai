// MARK: MODIFIED FILE - Views/ImageListView.swift
// File: BrickAI/Views/ImageListView.swift
// Removed Nav Title/Toolbar which were moved to ImageListContentView.

import SwiftUI

struct ImageListView: View {
    // Observe the ImageDataManager directly from the environment
    @EnvironmentObject var imageDataManager: ImageDataManager
    // Access user manager for potential logout action from alert
    @EnvironmentObject var userManager: UserManager
    // State to manage alert presentation based on ImageDataManager's error
    @State private var showErrorAlert = false

    var body: some View {
        // Apply alert and onChange modifiers directly to NavigationView
        NavigationView {
            // Use a Group to switch between the extracted subviews
            Group {
                if imageDataManager.isLoadingList && imageDataManager.images.isEmpty {
                    // Show initial loading view
                    LoadingView()
                } else if imageDataManager.images.isEmpty && imageDataManager.listError == nil && !imageDataManager.isLoadingList {
                    // Show empty state view
                    EmptyListView()
                } else {
                    // Show the main list content view
                    // Pass down environment objects if needed by sub-components (like ImageRow)
                    ImageListContentView()
                        .environmentObject(imageDataManager)
                }
            }

        } // End NavigationView
        // --- Error Handling Alert & onChange remain attached to NavigationView ---
        .onChange(of: imageDataManager.listError) { _, newError in
            showErrorAlert = (newError != nil)
        }
        .alert("Error Loading Images", isPresented: $showErrorAlert, presenting: imageDataManager.listError) { error in
            Button("Retry") {
                imageDataManager.prepareImageData()
            }
            if case .sessionExpired = error {
                Button("Log Out", role: .destructive) {
                    // Note: Actual logout + cache clear should happen in SettingsView ideally
                     userManager.clearUser()
                }
            } else if case .authenticationTokenMissing = error {
                 Button("Log Out", role: .destructive) {
                     userManager.clearUser()
                 }
            } else {
                 Button("OK", role: .cancel) { }
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

// MARK: END MODIFIED FILE - Views/ImageListView.swift
