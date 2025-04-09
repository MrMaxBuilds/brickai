// MARK: MODIFIED FILE - Views/ImageList/ImageListContentView.swift
// File: BrickAI/Views/ImageList/ImageListContentView.swift
// Simplified ProgressIndicatorOverlay by removing GeometryReader and using standard overlay alignment.

import SwiftUI

struct ImageListContentView: View {
    // Needs the data manager to get the images and handle refresh
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        List {
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
        .navigationTitle("Images")
    }
}
