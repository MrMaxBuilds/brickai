// MARK: MODIFIED FILE - Views/ImageListView2.swift
// Displays images in a continuous vertical scroll. Each acknowledged image card
// takes up approximately 80% of the screen height.

import SwiftUI

struct ImageListView: View {
    @EnvironmentObject var imageDataManager: ImageDataManager
    @EnvironmentObject var userManager: UserManager
    @State private var showErrorAlert = false

    var body: some View {
        NavigationView { // Or NavigationStack
            Group {
                if imageDataManager.isLoadingList && imageDataManager.images.isEmpty && imageDataManager.pendingUploads.isEmpty {
                    LoadingView()
                } else if imageDataManager.images.isEmpty && imageDataManager.pendingUploads.isEmpty && imageDataManager.listError == nil && !imageDataManager.isLoadingList {
                    EmptyListView()
                } else {
                    ImageListContentView2()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .onChange(of: imageDataManager.listError) { _, newError in
                showErrorAlert = (newError != nil)
            }
            .alert("Error Loading Images", isPresented: $showErrorAlert, presenting: imageDataManager.listError) { error in
                Button("Retry") { imageDataManager.prepareImageData() }
                if case .sessionExpired = error { Button("Log Out", role: .destructive) { userManager.clearUser() } }
                else if case .authenticationTokenMissing = error { Button("Log Out", role: .destructive) { userManager.clearUser() } }
                else { Button("OK", role: .cancel) { } }
            } message: { error in Text(error.localizedDescription) }
        }
        .environmentObject(imageDataManager)
        .environmentObject(userManager)
    }
}

struct ImageListContentView2: View {
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 20) { // Spacing between cards
                    // Section for Pending Uploads (smaller cards)
                    if !imageDataManager.pendingUploads.isEmpty {
                        Section {
                            ForEach(imageDataManager.pendingUploads) { pendingItem in
                                PendingImageCardView(pendingUpload: pendingItem)
                                    .padding(.horizontal)
                            }
                        } header: {
                            Text("Currently Uploading")
                                .font(.headline)
// <-----CHANGE START------>
                                .foregroundColor(Color(UIColor.systemGray)) // Adjusted for black background
// <-----CHANGE END-------->
                                .padding(.top)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 10)
                    }

                    // Acknowledged Images (large cards, 80% screen height)
                    if !imageDataManager.images.isEmpty {
                        let cardHeight = geometry.size.height * 0.8 // Calculate 80% of screen height

                        ForEach(imageDataManager.images) { image in
                            AcknowledgedImageCardView(image: image, cardHeight: cardHeight)
                                .padding(.horizontal) // Horizontal padding for the card in the list
                        }
                    }
                }
                .padding(.vertical) // Padding at the top and bottom of the LazyVStack
            }
            .refreshable {
                print("ImageListContentView2: Refresh triggered.")
                imageDataManager.prepareImageData()
            }
        }
        .navigationTitle("Creations")
        .navigationBarTitleDisplayMode(.inline)
// <-----CHANGE START------>
        .preferredColorScheme(.dark) // Ensures nav bar items are light on a dark bar
// <-----CHANGE END-------->
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Creations").font(.headline) // Color will be handled by preferredColorScheme
                    let totalCount = imageDataManager.images.count + imageDataManager.pendingUploads.count
                    if totalCount > 0 {
                        Text("(\(totalCount) total)")
                            .font(.caption)
                            .foregroundColor(.secondary) // Secondary color on dark bar should be light gray
                    }
                }
            }
        }
    }
}

struct AcknowledgedImageCardView: View {
    let image: ImageData
    let cardHeight: CGFloat

    var body: some View {
        ImageListCardView(image: image, cardHeight: cardHeight)
    }
}

struct PendingImageCardView: View {
    let pendingUpload: PendingUploadInfo
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 15) {
                Image(systemName: pendingUpload.placeholderImageName)
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30)
                    .foregroundColor(.secondary).padding(15).frame(width: 60, height: 60)
// <-----CHANGE START------>
                    .background(Color(UIColor.systemGray4)) // Differentiated icon background
// <-----CHANGE END-------->
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: Uploading...").font(.headline).foregroundColor(.orange)
// <-----CHANGE START------>
                    Text("Added: \(pendingUpload.createdAt, style: .relative) ago").font(.caption).foregroundColor(Color(UIColor.systemGray)) // Adjusted for card background
// <-----CHANGE END-------->
                }
                Spacer()
                ProgressView().scaleEffect(0.9)
            }
        }
// <-----CHANGE START------>
        .padding().background(Color(UIColor.systemGray5)) // New card background
// <-----CHANGE END-------->
        .cornerRadius(12).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(0.8)
    }
}

// MARK: END MODIFIED FILE - Views/ImageListView2.swift
