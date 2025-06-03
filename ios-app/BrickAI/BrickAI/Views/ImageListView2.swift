// MARK: MODIFIED FILE - Views/ImageListView2.swift
// This file provides an alternative to ImageListView, displaying images in a vertical scroll of cards.
// Updated AcknowledgedImageCardView to use the new ImageListCardView.

import SwiftUI

// MARK: - Main List View (Replaces ImageListView)

struct ImageListView2: View {
    @EnvironmentObject var imageDataManager: ImageDataManager
    @EnvironmentObject var userManager: UserManager // For logout action from alert
    @State private var showErrorAlert = false

    var body: some View {
        NavigationView {
            Group {
                if imageDataManager.isLoadingList && imageDataManager.images.isEmpty && imageDataManager.pendingUploads.isEmpty {
                    LoadingView() // Re-use existing LoadingView
                } else if imageDataManager.images.isEmpty && imageDataManager.pendingUploads.isEmpty && imageDataManager.listError == nil && !imageDataManager.isLoadingList {
                    EmptyListView() // Re-use existing EmptyListView
                } else {
                    ImageListContentView2()
                        // EnvironmentObjects are passed down if needed by child components
                }
            }
            // Error Handling Alert (similar to ImageListView)
            .onChange(of: imageDataManager.listError) { _, newError in
                showErrorAlert = (newError != nil)
            }
            .alert("Error Loading Images", isPresented: $showErrorAlert, presenting: imageDataManager.listError) { error in
                Button("Retry") {
                    imageDataManager.prepareImageData()
                }
                if case .sessionExpired = error {
                    Button("Log Out", role: .destructive) {
                        userManager.clearUser()
                        // Optionally, also clear image cache and stop polling if appropriate here
                        // imageDataManager.clearCache()
                        // imageDataManager.stopPolling()
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
        .environmentObject(imageDataManager)
        .environmentObject(userManager)
    }
}

// MARK: - Content View for the Card List

struct ImageListContentView2: View {
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .center, spacing: 20) {
                // Display Pending Uploads First
                if !imageDataManager.pendingUploads.isEmpty {
                    Section {
                        ForEach(imageDataManager.pendingUploads) { pendingItem in
                            PendingImageCardView(pendingUpload: pendingItem) // Existing pending card
                        }
                    } header: {
                        Text("Currently Uploading")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                }

                // Display Acknowledged Images Second
                if !imageDataManager.images.isEmpty {
                     Section {
                        ForEach(imageDataManager.images) { image in
                            //<-----CHANGE START------>
                            // Use the modified AcknowledgedImageCardView which now embeds ImageListCardView
                            AcknowledgedImageCardView(image: image)
                            //<-----CHANGE END-------->
                        }
                    } header: {
                        // Show header only if there are also pending items, or if it's the only section
                        if !imageDataManager.pendingUploads.isEmpty || imageDataManager.images.count > 0 {
                             Text("My Creations") // Changed header text slightly
                                 .font(.headline)
                                 .foregroundColor(.secondary)
                                 .padding(.top)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .refreshable {
            print("ImageListContentView2: Refresh triggered.")
            imageDataManager.prepareImageData()
        }
        .navigationTitle("My Images")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("My Images").font(.headline)
                    let totalCount = imageDataManager.images.count + imageDataManager.pendingUploads.count
                    if totalCount > 0 {
                        Text("(\(totalCount) total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Container Card View for Acknowledged Images
// This view now directly embeds the new ImageListCardView.

struct AcknowledgedImageCardView: View {
    let image: ImageData
    // ImageDataManager will be passed to ImageListCardView via its own @EnvironmentObject
    // No need to explicitly pass it here if ImageListCardView declares it.

    var body: some View {
        //<-----CHANGE START------>
        // Directly embed the new ImageListCardView.
        // ImageListCardView handles its own styling (background, cornerRadius, shadow).
        ImageListCardView(image: image)
        // No NavigationLink here, as ImageListCardView handles taps for FullScreenImageView.
        //<-----CHANGE END-------->
    }
}

// MARK: - Card View for Pending Images (Remains Unchanged from previous version)

struct PendingImageCardView: View {
    let pendingUpload: PendingUploadInfo

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 15) {
                Image(systemName: pendingUpload.placeholderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.secondary)
                    .padding(15)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: Uploading...")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Added: \(pendingUpload.createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                ProgressView()
                    .scaleEffect(0.9)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(0.8)
    }
}

// MARK: - Preview
/*
struct ImageListView2_Previews: PreviewProvider {
    static var previews: some View {
        let mockUserManager = UserManager.shared
        let mockImageDataManager = ImageDataManager()
        // mockImageDataManager.images = ImageData.previewData // Example data
        // mockImageDataManager.pendingUploads = [PendingUploadInfo()] // Example data

        ImageListView2()
            .environmentObject(mockImageDataManager)
            .environmentObject(mockUserManager)
    }
}
*/

// Helper for date formatting (if not available elsewhere)
// extension Date.FormatStyle.DateStyle {
//    static var friendly: Date.FormatStyle.DateStyle {
//        .abbreviated
//    }
// }

// MARK: END MODIFIED FILE - Views/ImageListView2.swift