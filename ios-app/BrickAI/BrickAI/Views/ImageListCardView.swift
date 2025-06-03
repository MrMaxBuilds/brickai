// MARK: NEW FILE - Views/ImageList/ImageListCardView.swift
// Displays a card with a horizontal paging scroll view for an image's original/processed versions.
// Includes subtle status, date, and a save button.
// Tapping an image in the scroll view navigates to FullScreenImageView.

import SwiftUI

// Helper View for Displaying a Single Image within the Card's ScrollView
// Similar to AsyncImageView in ImageDetailView, but tailored for this card context if needed.
// For simplicity, we assume AsyncImageView from ImageDetailView.swift is accessible or we'd redefine it here.
// If AsyncImageView is not globally accessible, you would define a similar struct here.
// For this example, I'll proceed as if a similar view construction is used.

struct ImageListCardView: View {
    let image: ImageData

    // Environment/State Objects
    @EnvironmentObject var imageDataManager: ImageDataManager
    @StateObject private var photoLibraryManager = PhotoLibraryManager() // For save functionality

    // State for Horizontal ScrollView
    @State private var visibleImageUrl: URL?

    // State for Save Button
    @State private var isSaving = false
    @State private var showSaveAlert = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""

    // State for Fullscreen Tap
    @State private var isShowingFullScreenImage = false
    @State private var tappedImageForFullScreen: ImageData? // Store the ImageData for fullscreen

    // Computed property to check if scroll view should be used
    var canShowBothImages: Bool {
        image.originalImageUrl != nil && image.processedImageUrl != nil
    }

    // Determine the URL to show initially or if only one exists
    var initialOrOnlyImageUrl: URL? {
        image.processedImageUrl ?? image.originalImageUrl
    }

    // Helper to determine status color (can be made more subtle if needed by adjusting color values)
    private func statusColor(status: String) -> Color {
        switch status.uppercased() {
        case "UPLOADED", "PROCESSING": return .orange.opacity(0.8)
        case "COMPLETED": return .green.opacity(0.8)
        case "FAILED": return .red.opacity(0.8)
        default: return .secondary // More subtle default
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { // Reduced spacing
            // --- Image Display Area (Horizontal Paging ScrollView) ---
            Group {
                if canShowBothImages {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 0) {
                                if let originalUrl = image.originalImageUrl {
                                    // Using AsyncImageView directly if accessible, or a local equivalent
                                    AsyncImageView(url: originalUrl) // Assumes AsyncImageView from ImageDetailView
                                        .environmentObject(imageDataManager)
                                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                        .id(originalUrl)
                                        .onTapGesture {
                                            self.tappedImageForFullScreen = image // Pass the whole object
                                            self.isShowingFullScreenImage = true
                                        }
                                }
                                if let processedUrl = image.processedImageUrl {
                                    AsyncImageView(url: processedUrl) // Assumes AsyncImageView from ImageDetailView
                                        .environmentObject(imageDataManager)
                                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                        .id(processedUrl)
                                        .onTapGesture {
                                            self.tappedImageForFullScreen = image // Pass the whole object
                                            self.isShowingFullScreenImage = true
                                        }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $visibleImageUrl)
                        .frame(height: 220) // Consistent height for the image scroller
                        .clipShape(RoundedRectangle(cornerRadius: 10)) // Clip the scroll view
                        .onAppear {
                            let targetUrl = image.processedImageUrl ?? image.originalImageUrl
                            visibleImageUrl = targetUrl
                            if let targetUrl {
                                proxy.scrollTo(targetUrl, anchor: .center)
                            }
                        }
                    }
                } else {
                    // Fallback: Show only the single available image
                    AsyncImageView(url: initialOrOnlyImageUrl) // Assumes AsyncImageView from ImageDetailView
                        .environmentObject(imageDataManager)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            self.tappedImageForFullScreen = image // Pass the whole object
                            self.isShowingFullScreenImage = true
                        }
                        .onAppear {
                            visibleImageUrl = initialOrOnlyImageUrl
                        }
                }
            }
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2) // Subtle shadow for image area

            // Page Indicator Dots (if multiple images)
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
                 .padding(.top, 4) // Small padding for dots
            }

            // --- Subtle Status, Date, and Save Button ---
            HStack(alignment: .center) {
                // Status and Date (more subtle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(image.status.capitalized)
                        .font(.caption) // Smaller font
                        .fontWeight(.medium)
                        .foregroundColor(statusColor(status: image.status))
                    Text(image.createdAt.formatted(date: .abbreviated, time: .omitted)) // Date only, more subtle
                        .font(.caption2) // Even smaller font
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Save Button
                if isSaving {
                    ProgressView().frame(width: 30, height: 30)
                } else {
                    Button {
                        initiateSaveProcess()
                    } label: {
                        Image(systemName: "arrow.down.circle") // Using a less filled icon for subtlety
                            .font(.title3) // Slightly smaller
                            .foregroundColor(.blue.opacity(0.9))
                    }
                    .frame(width: 30, height: 30)
                    .disabled(visibleImageUrl == nil) // Disable if no image is visible to save
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8) // Reduced vertical padding

        } // End Main VStack for Card
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2) // Main card shadow
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text(saveAlertTitle), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(item: $tappedImageForFullScreen) { imageDataItem in
            // Pass the whole ImageData object to the fullscreen view
            FullScreenImageView(imageData: imageDataItem)
               .environmentObject(imageDataManager) // Pass manager
        }
        // If AsyncImageView is defined in ImageDetailView.swift and not globally,
        // you'd need to ensure it's accessible or redefine a similar helper here.
        // For this example, we assume AsyncImageView is usable.
    }

    // --- Helper Functions for Saving ---
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

// This makes ImageData identifiable for the .fullScreenCover(item: ...) modifier
// extension ImageData: Identifiable {} // This might already be defined in ImageData.swift; if not, it's needed.

// MARK: END NEW FILE - Views/ImageList/ImageListCardView.swift