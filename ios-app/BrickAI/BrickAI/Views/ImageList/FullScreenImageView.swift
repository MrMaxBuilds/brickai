// File: BrickAI/Views/ImageList/FullScreenImageView.swift
// Updated to include download button functionality from ImageDetailView
// Now accepts ImageData instead of just Image
// Added drag-down-to-dismiss gesture
// Removed explicit 'X' close button

import SwiftUI

struct FullScreenImageView: View {
    // Input: ImageData object
// <-----CHANGE START------>
    let imageDataForDetails: ImageData // Renamed from imageData
    let actualUrlToDisplay: URL        // The specific URL to show
// <-----CHANGE END-------->

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

// <-----CHANGE START------>
    // Initializer
    init(imageDataForDetails: ImageData, actualUrlToDisplay: URL) {
        self.imageDataForDetails = imageDataForDetails
        self.actualUrlToDisplay = actualUrlToDisplay
    }
// <-----CHANGE END-------->

    var body: some View {
        // Determine the URL and check cache
// <-----CHANGE START------>
        let imageUrl = actualUrlToDisplay // Use the specific URL passed in
// <-----CHANGE END-------->
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
                 } else { // Removed "if let url = imageUrl" because imageUrl (actualUrlToDisplay) is non-optional
                     AsyncImage(url: imageUrl) { phase in // Use imageUrl directly
                         switch phase {
                         case .empty: ProgressView().tint(.white)
                         case .success(let loadedImage): loadedImage.resizable().scaledToFit()
                         case .failure: Image(systemName: "photo.fill").foregroundColor(.secondary)
                         @unknown default: EmptyView()
                         }
                     }
                     .onAppear { imageDataManager.ensureImageIsCached(for: imageUrl) } // Use imageUrl directly
                 }
                 // Removed "else" block for "photo.fill" as imageUrl is non-optional
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
                         // .disabled(imageUrl == nil) // imageUrl (actualUrlToDisplay) is non-optional
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
                // let velocityThreshold: CGFloat = 300 // Not used in this logic
                
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
// <-----CHANGE START------>
        let urlToSave = self.actualUrlToDisplay // Use the specific URL that is being displayed
// <-----CHANGE END-------->
        isSaving = true
        if let cachedUIImage = imageDataManager.getImage(for: urlToSave) {
             print("FullScreenImageView: Saving cached image.")
             photoLibraryManager.saveImage(cachedUIImage) { result in handleSaveCompletion(result: result) }
        } else {
             print("FullScreenImageView: Image not cached. Requesting download and save.")
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
    
} // End struct

// --- Preview (Unchanged) ---
struct FullScreenImageView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImageData = ImageData.previewData[0]
        let mockDataManager = ImageDataManager()

// <-----CHANGE START------>
        // Ensure a valid URL from sampleImageData is used for actualUrlToDisplay
        let displayUrl = sampleImageData.processedImageUrl ?? sampleImageData.originalImageUrl!

        FullScreenImageView(imageDataForDetails: sampleImageData, actualUrlToDisplay: displayUrl)
            .environmentObject(mockDataManager)
// <-----CHANGE END-------->
    }
}