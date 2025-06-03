// MARK: MODIFIED FILE - Views/ImageList/ImageListCardView.swift
// Displays a card where the image takes up most of the card's height (approx 80% of screen height).
// Image fills its allocated space, cropping if necessary.
// Includes a horizontal paging scroll view for original/processed versions.
// Subtle status, date, and save button are overlaid or placed below the image.
// Improved caching logic in ImageItemView.

import SwiftUI

struct ImageListCardView: View {
    let image: ImageData
    let cardHeight: CGFloat

    @EnvironmentObject var imageDataManager: ImageDataManager
    @StateObject private var photoLibraryManager = PhotoLibraryManager()

    @State private var visibleImageUrl: URL?
    @State private var isSaving = false
    @State private var showSaveAlert = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    @State private var tappedImageForFullScreen: ImageData?

    private var controlsAreaHeight: CGFloat { cardHeight * 0.15 < 60 ? 60 : cardHeight * 0.15 }
    private var imageDisplayAreaHeight: CGFloat { cardHeight - controlsAreaHeight }

    var canShowBothImages: Bool {
        image.originalImageUrl != nil && image.processedImageUrl != nil
    }

    var initialOrOnlyImageUrl: URL? {
        image.processedImageUrl ?? image.originalImageUrl
    }

    private func statusColor(status: String) -> Color {
        switch status.uppercased() {
        case "UPLOADED", "PROCESSING": return .orange.opacity(0.9)
        case "COMPLETED": return .green.opacity(0.9)
        case "FAILED": return .red.opacity(0.9)
        default: return .secondary.opacity(0.8)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { imageGeo in
                Group {
                    if canShowBothImages {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 0) {
                                    if let originalUrl = image.originalImageUrl {
                                        ImageItemView(url: originalUrl, parentSize: imageGeo.size, targetHeight: imageDisplayAreaHeight)
                                            .id(originalUrl)
                                            .onTapGesture { self.tappedImageForFullScreen = image }
                                    }
                                    if let processedUrl = image.processedImageUrl {
                                        ImageItemView(url: processedUrl, parentSize: imageGeo.size, targetHeight: imageDisplayAreaHeight)
                                            .id(processedUrl)
                                            .onTapGesture { self.tappedImageForFullScreen = image }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollIndicators(.hidden)
                            .scrollTargetBehavior(.paging)
                            .scrollPosition(id: $visibleImageUrl)
                            .onAppear {
                                let targetUrl = image.processedImageUrl ?? image.originalImageUrl
                                visibleImageUrl = targetUrl
                                if let targetUrl { proxy.scrollTo(targetUrl, anchor: .center) }
                            }
                        }
                    } else {
                        ImageItemView(url: initialOrOnlyImageUrl, parentSize: imageGeo.size, targetHeight: imageDisplayAreaHeight)
                            .onTapGesture { self.tappedImageForFullScreen = image }
                            .onAppear { visibleImageUrl = initialOrOnlyImageUrl }
                    }
                }
            }
            .frame(height: imageDisplayAreaHeight)
            .clipped()

            VStack(spacing: 4) {
                if canShowBothImages {
                     HStack(spacing: 6) {
                          if let url = image.originalImageUrl {
                              Circle().fill(visibleImageUrl == url ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                          }
                          if let url = image.processedImageUrl {
                              Circle().fill(visibleImageUrl == url ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                          }
                     }
                     .frame(maxWidth: .infinity)
                     .padding(.top, 8)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(image.status.capitalized)
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(statusColor(status: image.status))
                        Text(image.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if isSaving {
                        ProgressView().frame(width: 30, height: 30)
                    } else {
                        Button { initiateSaveProcess() } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3).foregroundColor(.blue.opacity(0.9))
                        }
                        .frame(width: 30, height: 30)
                        .disabled(visibleImageUrl == nil)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .padding(.top, canShowBothImages ? 0 : 8)
            }
            .frame(height: controlsAreaHeight)
            .frame(maxWidth: .infinity)
        }
        .frame(height: cardHeight)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
        .clipped()
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text(saveAlertTitle), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(item: $tappedImageForFullScreen) { imageDataItem in
            FullScreenImageView(imageData: imageDataItem)
               .environmentObject(imageDataManager)
        }
    }

    private func initiateSaveProcess() {
        guard let urlToSave = visibleImageUrl else {
            presentSaveAlert(success: false, message: "No image selected to save.")
            return
        }
        isSaving = true
        if let cachedUIImage = imageDataManager.getImage(for: urlToSave) {
            photoLibraryManager.saveImage(cachedUIImage) { result in handleSaveCompletion(result: result) }
        } else {
            photoLibraryManager.downloadAndSaveImage(url: urlToSave, imageDataManager: imageDataManager) { result in handleSaveCompletion(result: result) }
        }
    }

    private func handleSaveCompletion(result: Result<Void, Error>) {
         DispatchQueue.main.async {
              isSaving = false
              switch result {
              case .success: presentSaveAlert(success: true, message: "Image saved to Photos.")
              case .failure(let error): presentSaveAlert(success: false, message: error.localizedDescription)
              }
         }
    }

    private func presentSaveAlert(success: Bool, message: String) {
         saveAlertTitle = success ? "Success" : "Error"
         saveAlertMessage = message
         showSaveAlert = true
    }
}

// Helper view to render each image within the horizontal scroller
struct ImageItemView: View {
    let url: URL?
    let parentSize: CGSize
    let targetHeight: CGFloat

    @EnvironmentObject var imageDataManager: ImageDataManager
    //<-----CHANGE START------>
    @State private var locallyCachedUIImage: UIImage? = nil
    @State private var isLoadingCoreDataCache: Bool = true // Initially true to check Core Data
    //<-----CHANGE END-------->

    var body: some View {
        Group {
            //<-----CHANGE START------>
            if isLoadingCoreDataCache {
                // Placeholder while checking our Core Data cache
                ZStack {
                    Color(.systemGray5) // Consistent placeholder background
                    ProgressView()
                }
            } else if let uiImage = locallyCachedUIImage {
                // Image successfully loaded from Core Data cache
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill) // Fill the frame, crop if necessary
            } else if let imageURL = url {
                // Not in Core Data, fall back to SwiftUI.AsyncImage
                // AsyncImage handles its own network fetching and URLCache
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            // Optional: If AsyncImage loads successfully, we could try to update
                            // our Core Data cache here too, if not already handled by ensureImageIsCached.
                            // For simplicity, ensureImageIsCached in .task handles this.
                    } else if phase.error != nil {
                        ZStack {
                            Color(.systemGray4)
                            Image(systemName: "photo.fill.on.rectangle.fill")
                                .resizable().scaledToFit().foregroundColor(.secondary).padding()
                        }
                    } else { // Loading phase of AsyncImage
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }
                    }
                }
            } else { // URL is nil
                ZStack {
                    Color(.systemGray4)
                    Image(systemName: "photo.fill")
                        .resizable().scaledToFit().foregroundColor(.secondary).padding()
                }
            }
            //<-----CHANGE END-------->
        }
        .frame(width: parentSize.width, height: targetHeight)
        .clipped()
        //<-----CHANGE START------>
        .task { // Replaced .onAppear with .task for async work
            guard isLoadingCoreDataCache, let imageURL = url else {
                // If not loading cache anymore, or URL is nil, no need to proceed
                if url == nil { isLoadingCoreDataCache = false }
                return
            }

            // Attempt to load from ImageDataManager's Core Data cache
            // This is a synchronous call on MainActor within ImageDataManager
            let cachedImage = imageDataManager.getImage(for: imageURL)

            if let img = cachedImage {
                self.locallyCachedUIImage = img
            } else {
                // Not found in Core Data.
                // Trigger ImageDataManager to download and store it in Core Data for future use.
                // This happens in the background and doesn't block SwiftUI.AsyncImage.
                imageDataManager.ensureImageIsCached(for: imageURL)
            }
            self.isLoadingCoreDataCache = false // Finished checking/triggering Core Data cache
        }
        //<-----CHANGE END-------->
    }
}

// MARK: END MODIFIED FILE - Views/ImageList/ImageListCardView.swift
