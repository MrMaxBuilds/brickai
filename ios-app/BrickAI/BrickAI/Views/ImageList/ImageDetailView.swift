// MARK: MODIFIED FILE - Views/ImageDetailView.swift
// File: BrickAI/Views/ImageDetailView.swift
// Refactored image display to use a paging ScrollView for swiping between original/processed.
// Added AsyncImageView helper view.

import SwiftUI

// <<< ADDED: Helper View for Displaying a Single Image >>>
struct AsyncImageView: View {
    let url: URL? // The URL to display
    // Use observed object if the manager instance lifecycle is tied elsewhere,
    // or environment object if passed down consistently. Let's assume EnvironmentObject.
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        let cachedImage = imageDataManager.getImage(for: url)

        Group {
            if let loadedImage = cachedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
            } else if let displayUrl = url {
                AsyncImage(url: displayUrl) { phase in
                    switch phase {
                    case .empty: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemGray6)) // Ensure progress fills space
                    case .success(let loadedImage): loadedImage.resizable().scaledToFit()
                    case .failure: VStack { Image(systemName: "photo.fill.on.rectangle.fill").font(.largeTitle).foregroundColor(.secondary); Text("Failed to load").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemGray6)) // Fill space on failure
                    @unknown default: EmptyView()
                    }
                }
                .onAppear { imageDataManager.ensureImageIsCached(for: displayUrl) }
            } else {
                 // Placeholder if URL is nil
                 VStack { Image(systemName: "photo.fill.on.rectangle.fill").font(.largeTitle).foregroundColor(.secondary); Text("Not available").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemGray6))
            }
        }
        // Common modifiers for the image container can go here if needed
        .clipShape(RoundedRectangle(cornerRadius: 10)) // Clip the content area
        .shadow(radius: 3) // Add a subtle shadow perhaps
    }
}


// --- Main Detail View ---
struct ImageDetailView: View {
    let image: ImageData
    // Environment/State Objects
    @EnvironmentObject var imageDataManager: ImageDataManager
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    // State for Save Button
    @State private var isSaving = false
    @State private var showSaveAlert = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    
    // State for Fullscreen Tap
    @State private var isShowingFullScreenImage = false

    // <<< REVISED: State for tracking visible image in ScrollView >>>
    // Use the URL as the ID. Default to processed if available.
    @State private var visibleImageUrl: URL?

    // Computed property to check if scroll view should be used
    var canShowBothImages: Bool {
        image.originalImageUrl != nil && image.processedImageUrl != nil
    }
    
    // Determine the URL to show initially or if only one exists
    var initialOrOnlyImageUrl: URL? {
        image.processedImageUrl ?? image.originalImageUrl
    }

    var body: some View {
        ScrollView(.vertical) { // Main scroll view is now vertical for details
            VStack(alignment: .leading, spacing: 20) {

                // --- Image Display Area (Uses ScrollView or Single Image) ---
                if canShowBothImages {
                    // <<< ADDED: Paging ScrollView for Original/Processed >>>
                    ScrollViewReader { proxy in // To set initial scroll position
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 0) { // LazyHStack is efficient
                                // Original Image View
                                if let originalUrl = image.originalImageUrl {
                                    AsyncImageView(url: originalUrl)
                                         .environmentObject(imageDataManager) // Pass down manager
                                         .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                         .id(originalUrl) // ID for scrolling/tracking
                                         .onTapGesture { handleImageTap(url: originalUrl) } // Tap for fullscreen
                                }

                                // Processed Image View
                                if let processedUrl = image.processedImageUrl {
                                     AsyncImageView(url: processedUrl)
                                          .environmentObject(imageDataManager) // Pass down manager
                                          .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                          .id(processedUrl) // ID for scrolling/tracking
                                          .onTapGesture { handleImageTap(url: processedUrl) } // Tap for fullscreen
                                }
                            }
                            .scrollTargetLayout() // Define layout for target behavior
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $visibleImageUrl) // Track visible page URL ID
                        // Set a reasonable height for the image scroll area
                        .frame(height: 350) // Adjust height as needed
                        .clipShape(RoundedRectangle(cornerRadius: 10)) // Clip the scroll view itself
                        .shadow(radius: 5)
                        .onAppear {
                             // Set initial scroll position and state
                             let targetUrl = image.processedImageUrl ?? image.originalImageUrl // Default to processed
                             visibleImageUrl = targetUrl // Set initial state
                             if let targetUrl {
                                  // Scroll without animation initially
                                 proxy.scrollTo(targetUrl, anchor: .center)
                                 print("ImageDetailView: Paging ScrollView appeared. Initial target: \(targetUrl.absoluteString)")
                             }
                        }
                    } // End ScrollViewReader
                    .padding(.horizontal) // Padding for the scroll view block

                } else {
                    // Fallback: Show only the single available image
                     AsyncImageView(url: initialOrOnlyImageUrl)
                          .environmentObject(imageDataManager)
                          .frame(height: 350) // Maintain similar height
                          .clipShape(RoundedRectangle(cornerRadius: 10))
                          .shadow(radius: 5)
                          .onTapGesture { handleImageTap(url: initialOrOnlyImageUrl) } // Tap for fullscreen
                          .padding(.horizontal)
                          .onAppear {
                              // Update state if only one image is shown
                              visibleImageUrl = initialOrOnlyImageUrl
                              print("ImageDetailView: Single image view appeared. URL: \(initialOrOnlyImageUrl?.absoluteString ?? "None")")
                          }
                }
                // --- End Image Display Area ---

                // <<< ADDED: Page Indicator Dots (Optional) >>>
                if canShowBothImages {
                     HStack(spacing: 8) {
                          // Original Dot
                          if let url = image.originalImageUrl {
                              Circle().fill(visibleImageUrl == url ? .primary : .secondary).frame(width: 8, height: 8)
                          }
                          // Processed Dot
                          if let url = image.processedImageUrl {
                              Circle().fill(visibleImageUrl == url ? .primary : .secondary).frame(width: 8, height: 8)
                          }
                     }
                     .frame(maxWidth: .infinity) // Center the dots
                     .padding(.top, -10) // Adjust spacing relative to image view
                }

                // --- Status and Download Button Row ---
                HStack {
                     Text("Status: \(image.status.capitalized)")
                         .font(.title2)
                         .fontWeight(.semibold)
                     Spacer()
                     if isSaving { ProgressView().frame(width: 44, height: 44) } else {
                         Button { initiateSaveProcess() } label: { Image(systemName: "arrow.down.circle.fill").font(.title).foregroundColor(.blue) }
                           .frame(width: 44, height: 44)
                           // <<< CHANGED: Disable based on currently visible tracked URL >>>
                           .disabled(visibleImageUrl == nil)
                     }
                }
                .padding(.horizontal)

                // --- Remaining Details Section --- (Unchanged)
                VStack(alignment: .leading, spacing: 10) {
                     Divider()
                     Text("Uploaded")
                         .font(.headline)
                     Text(image.createdAt.formatted(date: .long, time: .shortened))
                          .font(.body)
                          .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer() // Pushes content up in the vertical ScrollView
            }
            .padding(.vertical)
        } // End Main Vertical ScrollView
        .navigationTitle("Image Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showSaveAlert) { // Save Alert (Unchanged)
            Alert(title: Text(saveAlertTitle), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $isShowingFullScreenImage) { // Fullscreen Cover (Unchanged)
             // Pass the whole ImageData object to the fullscreen view
            FullScreenImageView(imageData: image)
               .environmentObject(imageDataManager) // Pass manager
        }
        .environmentObject(imageDataManager) // Pass manager for AsyncImageView instances
        .onChange(of: visibleImageUrl) { _, newUrl in
            print("Visible image changed to: \(newUrl?.absoluteString ?? "None")")
            // Optional: Preload the *other* image if user pauses on one?
        }

    } // End body

    // --- Helper Functions ---

    // Helper to handle tap for fullscreen
    private func handleImageTap(url: URL?) {
        guard url != nil else { return } // Don't show fullscreen if URL is nil
        isShowingFullScreenImage = true
    }

    // <<< REVISED: Initiate save based on tracked visibleImageUrl >>>
    private func initiateSaveProcess() {
        guard let url = visibleImageUrl else { // Use the state variable tracking the visible URL
            presentSaveAlert(success: false, message: "Image URL not found.")
            return
        }
        isSaving = true
        if let cachedUIImage = imageDataManager.getImage(for: url) {
             print("ImageDetailView: Saving cached image for \(url.lastPathComponent).")
             photoLibraryManager.saveImage(cachedUIImage) { result in handleSaveCompletion(result: result) }
        } else {
             print("ImageDetailView: Image not cached (\(url.lastPathComponent)). Requesting download and save.")
             photoLibraryManager.downloadAndSaveImage(url: url, imageDataManager: imageDataManager) { result in handleSaveCompletion(result: result) }
        }
    }

    // handleSaveCompletion & presentSaveAlert remain the same
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
    
} // End struct

// MARK: END MODIFIED FILE - Views/ImageDetailView.swift
