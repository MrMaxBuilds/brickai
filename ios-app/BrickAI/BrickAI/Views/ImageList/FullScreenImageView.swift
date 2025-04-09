// File: BrickAI/Views/ImageList/FullScreenImageView.swift
// Updated to include download button functionality from ImageDetailView
// Now accepts ImageData instead of just Image
// Added drag-down-to-dismiss gesture
// Removed explicit 'X' close button

import SwiftUI

struct FullScreenImageView: View {
    // Input: ImageData object
    let imageData: ImageData

    // Environment variable for dismissing
    @Environment(\.dismiss) var dismiss
    
    // Manager Dependencies (for image loading & saving)
    @EnvironmentObject var imageDataManager: ImageDataManager
    @StateObject private var photoLibraryManager = PhotoLibraryManager()
    
    // State for Save Button
    @State private var isSaving = false
    @State private var showSaveAlert = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""

    // State for Drag Gesture
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        // Determine the URL and check cache
        let imageUrl = imageData.processedImageUrl ?? imageData.originalImageUrl
        let cachedImage = imageDataManager.getImage(for: imageUrl)

        ZStack {
            // Background color - Opacity changes during drag
            Color.black
                .opacity(calculateBackgroundOpacity())
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { // Tap background to dismiss
                     if dragOffset != .zero {
                         withAnimation(.interactiveSpring()) { dragOffset = .zero }
                     } else {
                          dismiss()
                     }
                }

            // --- Main Content Group (Image Display) ---
            Group {
                 if let loadedImage = cachedImage {
                     Image(uiImage: loadedImage)
                         .resizable()
                         .scaledToFit()
                 } else if let url = imageUrl {
                     AsyncImage(url: url) { phase in
                         switch phase {
                         case .empty: ProgressView().tint(.white)
                         case .success(let loadedImage): loadedImage.resizable().scaledToFit()
                         case .failure: Image(systemName: "photo.fill").foregroundColor(.secondary)
                         @unknown default: EmptyView()
                         }
                     }
                     .onAppear { imageDataManager.ensureImageIsCached(for: url) }
                 } else {
                     Image(systemName: "photo.fill")
                         .foregroundColor(.secondary)
                         .scaledToFit()
                 }
            }
            .offset(y: dragOffset.height) // Apply vertical offset based on drag
            .gesture(dragGesture) // Attach drag gesture to image content
            
            // --- Overlays for Buttons ---
            // Bottom Right: Download Button (Remains)
            VStack {
                 Spacer()
                 HStack {
                     Spacer()
                     if isSaving {
                         ProgressView().tint(.white)
                             .frame(width: 44, height: 44)
                             .padding()
                             .background(Color.black.opacity(0.5))
                             .clipShape(Circle())
                     } else {
                         Button { initiateSaveProcess() } label: {
                             Image(systemName: "arrow.down.circle.fill")
                                  .font(.largeTitle)
                                  .foregroundColor(.white)
                         }
                         .frame(width: 44, height: 44)
                         .padding()
                         .background(Color.black.opacity(0.5))
                         .clipShape(Circle())
                         .disabled(imageUrl == nil)
                     }
                 }
            }
            .padding([.bottom, .trailing])

        } // End ZStack
        .alert(isPresented: $showSaveAlert) { // Alert remains the same
            Alert(title: Text(saveAlertTitle), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
        }
        .environmentObject(imageDataManager)
        .animation(.interactiveSpring(), value: dragOffset)

    } // End body

    // Drag Gesture Definition (Unchanged)
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height >= 0 {
                    self.dragOffset = value.translation
                }
            }
            .onEnded { value in
                let dragThreshold: CGFloat = 100                
                if value.translation.height > dragThreshold || value.predictedEndTranslation.height > dragThreshold * 1.5 {
                    print("Drag ended: Dismissing view.")
                    dismiss()
                } else {
                    print("Drag ended: Snapping back.")
                    self.dragOffset = .zero
                }
            }
    }

    // Helper for Background Opacity (Unchanged)
    func calculateBackgroundOpacity() -> Double {
        let maxDragDistance: CGFloat = UIScreen.main.bounds.height * 0.7
        let dragProgress = max(0, min(1, dragOffset.height / maxDragDistance))
        return 1.0 - Double(dragProgress * 0.7)
    }

    // --- Helper Functions for Saving (Unchanged) ---
    private func initiateSaveProcess() {
        guard let url = imageData.processedImageUrl ?? imageData.originalImageUrl else {
            presentSaveAlert(success: false, message: "Image URL not found.")
            return
        }
        isSaving = true
        if let cachedUIImage = imageDataManager.getImage(for: url) {
             print("FullScreenImageView: Saving cached image.")
             photoLibraryManager.saveImage(cachedUIImage) { result in handleSaveCompletion(result: result) }
        } else {
             print("FullScreenImageView: Image not cached. Requesting download and save.")
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
    
} // End struct

// --- Preview (Unchanged) ---
struct FullScreenImageView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImageData = ImageData.previewData[0]
        let mockDataManager = ImageDataManager()

        FullScreenImageView(imageData: sampleImageData)
            .environmentObject(mockDataManager)
    }
}
