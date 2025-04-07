// MARK: MODIFIED FILE - Views/ImageList/ImageListContentView.swift
// File: BrickAI/Views/ImageList/ImageListContentView.swift
// Simplified ProgressIndicatorOverlay by removing GeometryReader and using standard overlay alignment.

import SwiftUI

// Extracted overlay view for progress indicators
struct ProgressIndicatorOverlay: View {
    // Receive state values from the parent view
    let isLoadingList: Bool
    let isPreloading: Bool
    let preloadingProgress: Double
    let hasImages: Bool // To determine if refresh indicator should show over existing images

    var body: some View {
        // MARK: <<< MODIFIED START >>>
        // Removed GeometryReader. The view now returns the ZStack/VStack directly.
        // Alignment is handled by the parent's .overlay modifier.
        // Use a VStack to arrange indicators vertically if both could appear (though current logic prevents this).
        // Add padding here to space it from the bottom edge.
        VStack(spacing: 2) {
            // Show spinner during refresh *only if* list already has images
            if isLoadingList && hasImages {
                 ProgressView().scaleEffect(0.8)
                     .padding(.bottom, 5) // Add some padding below spinner
            }

            // Show preloading bar
            if isPreloading {
                 ProgressView(value: preloadingProgress)
                     .progressViewStyle(LinearProgressViewStyle())
                 Text("Preloading recent images...")
                     .font(.caption)
                     .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal) // Horizontal padding for the content
        .padding(.bottom, 8) // Bottom padding from the screen edge
        .frame(maxWidth: .infinity) // Allow VStack to take full width for background/alignment
        // Optional: Add a background for better visibility over list content
        // .background(.thinMaterial) // Example background
        // .cornerRadius(5)
        .transition(.opacity) // Animate appearance
        .allowsHitTesting(false) // Prevent the overlay from blocking touches
        // MARK: <<< MODIFIED END >>>
    }
}


struct ImageListContentView: View {
    // Needs the data manager to get the images and handle refresh
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        // Apply overlay using the extracted view
        List {
            // Iterate over images from the manager
            ForEach(imageDataManager.images) { image in
                 NavigationLink(destination: ImageDetailView(image: image)) {
                      ImageRow(image: image)
                         .environmentObject(imageDataManager) // Pass manager to row
                 }
            }
        }
        .listStyle(.plain)
        .refreshable { // Pull-to-refresh triggers fetch in manager
             print("ImageListContentView: Refresh triggered.")
             imageDataManager.prepareImageData()
         }
        // MARK: <<< MODIFIED START >>>
        // Use standard overlay modifier with bottom alignment
        .overlay(alignment: .bottom) {
             // Use the extracted overlay view and pass state values
             ProgressIndicatorOverlay(
                 isLoadingList: imageDataManager.isLoadingList,
                 isPreloading: imageDataManager.isPreloading,
                 preloadingProgress: imageDataManager.preloadingProgress,
                 hasImages: !imageDataManager.images.isEmpty // Pass whether images exist
             )
        }
        // MARK: <<< MODIFIED END >>>
        // Moved Nav Title and Toolbar here
        .navigationTitle("My Images")
        .toolbar {
             ToolbarItem(placement: .navigationBarTrailing) {
                 Button {
                      // Manual refresh button triggers fetch in manager
                      imageDataManager.prepareImageData()
                 } label: {
                      Image(systemName: "arrow.clockwise")
                 }
                 // Disable refresh button only while list is actively loading
                 .disabled(imageDataManager.isLoadingList)
             }
        }
    }
}
