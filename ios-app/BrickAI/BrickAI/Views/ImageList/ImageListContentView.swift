// MARK: MODIFIED FILE - Views/ImageList/ImageListContentView.swift
// File: BrickAI/Views/ImageList/ImageListContentView.swift
// Simplified ProgressIndicatorOverlay by removing GeometryReader and using standard overlay alignment.
// Removed sections, displaying pending items first in a single list.

import SwiftUI

struct ImageListContentView: View {
    // Needs the data manager to get the images and handle refresh
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        List {
            //<-----CHANGE START------>
            // Display Pending Uploads First
            ForEach(imageDataManager.pendingUploads) { pendingItem in
                // Use the new PendingImageRow
                PendingImageRow(pendingUpload: pendingItem)
                    // No NavigationLink or EnvironmentObject needed here
            }

            // Display Acknowledged Images Second
            ForEach(imageDataManager.images) { image in
                NavigationLink(destination: ImageDetailView(image: image)) {
                    // Use the original (reverted) ImageRow
                    ImageRow(image: image)
                        .environmentObject(imageDataManager) // Pass manager to acknowledged row
                }
            }
            //<-----CHANGE END-------->
        }
        .listStyle(.plain) // Keep plain style for single section
        .refreshable { // Pull-to-refresh triggers fetch in manager
             print("ImageListContentView: Refresh triggered.")
             imageDataManager.prepareImageData()
         }
        // Toolbar with total count remains the same
        .navigationTitle("Images")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
             ToolbarItem(placement: .principal) {
                  VStack {
                       Text("Images").font(.headline)
                       Text("(\(imageDataManager.images.count + imageDataManager.pendingUploads.count) total)")
                           .font(.caption)
                           .foregroundColor(.secondary)
                  }
             }
        }
    }
}

// MARK: END MODIFIED FILE - Views/ImageList/ImageListContentView.swift