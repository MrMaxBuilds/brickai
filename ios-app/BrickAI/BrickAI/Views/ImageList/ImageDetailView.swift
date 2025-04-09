// MARK: MODIFIED FILE - Views/ImageDetailView.swift
// File: BrickAI/Views/ImageDetailView.swift
// Moved download button below image, aligned with Status text.

import SwiftUI

struct ImageDetailView: View {
    let image: ImageData
    // Get ImageDataManager from environment for cache checks
    @EnvironmentObject var imageDataManager: ImageDataManager
    // Use the PhotoLibraryManager for saving
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    // State for save feedback
    @State private var isSaving = false
    @State private var showSaveAlert = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { // Align VStack leading for text

                // --- Image Display (No changes here) ---
                let imageUrl = image.processedImageUrl ?? image.originalImageUrl
                let cachedImage = imageDataManager.getImage(for: imageUrl)

                Group {
                    if let loadedImage = cachedImage {
                        Image(uiImage: loadedImage)
                            .resizable().scaledToFit()
                    } else {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .empty: ProgressView().frame(height: 300).frame(maxWidth: .infinity) // Center progress
                            case .success(let loadedImage): loadedImage.resizable().scaledToFit()
                            case .failure: VStack { Image(systemName: "photo.fill.on.rectangle.fill").font(.largeTitle).foregroundColor(.secondary); Text("Failed to load image").foregroundColor(.secondary) }.frame(height: 300).frame(maxWidth: .infinity) // Center failure view
                            @unknown default: EmptyView()
                            }
                        }
                        .onAppear { imageDataManager.ensureImageIsCached(for: imageUrl) }
                    }
                }
                // Apply centering/padding specific to the image container if needed
                .frame(maxWidth: .infinity) // Keep image centered
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.horizontal) // Horizontal padding for the image block
                // --- End Image Display ---


                //<-----CHANGE START------>
                // --- Status and Download Button Row ---
                HStack {
                     // Status Text
                     Text("Status: \(image.status.capitalized)")
                         .font(.title2)
                         .fontWeight(.semibold)

                     Spacer() // Push button to the right

                     // Download Button / Progress Indicator
                     if isSaving {
                         ProgressView()
                             .frame(width: 44, height: 44) // Maintain size
                     } else {
                         Button {
                             initiateSaveProcess()
                         } label: {
                             Image(systemName: "arrow.down.circle.fill") // Using filled icon
                                  .font(.title) // Make icon slightly larger
                                  .foregroundColor(.blue)
                         }
                         .frame(width: 44, height: 44) // Ensure tappable area
                         .disabled(imageUrl == nil) // Disable if no URL
                     }
                }
                .padding(.horizontal) // Padding for this row
                // --- End Status and Download Button Row ---


                // --- Remaining Details Section ---
                VStack(alignment: .leading, spacing: 10) {
                     Divider() // Divider after Status/Button row

                     Text("Uploaded")
                         .font(.headline)
                     Text(image.createdAt.formatted(date: .long, time: .shortened))
                          .font(.body)
                          .foregroundColor(.secondary)
                }
                .padding(.horizontal) // Padding for remaining details
                //<-----CHANGE END-------->

                Spacer() // Pushes content up if ScrollView has extra space
            }
            .padding(.vertical) // Vertical padding for the outer VStack
        }
        .navigationTitle("Image Details")
        .navigationBarTitleDisplayMode(.inline)
        // --- Alert for Save Status ---
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text(saveAlertTitle), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        // Removed the .toolbar modifier
        // EnvironmentObject injection remains
        .environmentObject(imageDataManager)
    }

    // Functions initiateSaveProcess, handleSaveCompletion, presentSaveAlert remain exactly the same
    //<-----CHANGE START------>
    // (Functions are identical to previous step, just ensuring they are present)
    private func initiateSaveProcess() {
        guard let url = image.processedImageUrl ?? image.originalImageUrl else {
            presentSaveAlert(success: false, message: "Image URL not found.")
            return
        }
        isSaving = true
        if let cachedImage = imageDataManager.getImage(for: url) {
             print("ImageDetailView: Saving cached image.")
             photoLibraryManager.saveImage(cachedImage) { result in handleSaveCompletion(result: result) }
        } else {
             print("ImageDetailView: Image not cached. Requesting download and save.")
             photoLibraryManager.downloadAndSaveImage(url: url, imageDataManager: imageDataManager) { result in handleSaveCompletion(result: result) }
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
    //<-----CHANGE END-------->
}

// MARK: END MODIFIED FILE - Views/ImageDetailView.swift
