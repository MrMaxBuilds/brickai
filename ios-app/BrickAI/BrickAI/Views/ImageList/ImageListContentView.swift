// MARK: MODIFIED FILE - Views/ImageList/ImageListContentView.swift
// File: BrickAI/Views/ImageList/ImageListContentView.swift
// Simplified ProgressIndicatorOverlay by removing GeometryReader and using standard overlay alignment.

import SwiftUI

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
