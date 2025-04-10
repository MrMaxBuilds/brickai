// MARK: MODIFIED FILE - Views/CapturedImageView.swift
// File: BrickAI/Views/CapturedImageView.swift
// Modified upload action to be asynchronous and immediately dismiss the view.
// Added call to ImageDataManager to enqueue pending upload.
// Update ImageDataManager's lastUploadSuccessTime on successful upload.
// <-----CHANGE START------>
// Moved update of lastUploadSuccessTime to trigger immediately before upload starts.
// <-----CHANGE END-------->


import SwiftUI

struct CapturedImageView: View {
    let image: UIImage // The captured image to display/upload
    // Access the shared CameraManager instance to reset state
    @StateObject private var cameraManager = CameraManager.shared
    // Access ImageDataManager to add to pending queue and update success time
    @EnvironmentObject var imageDataManager: ImageDataManager

    // State variables for upload progress/status are no longer needed in this view
    // @State private var isUploading = false // REMOVED
    // @State private var uploadError: String? = nil // REMOVED
    // @State private var uploadSuccessURL: String? = nil // REMOVED

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Display the captured image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()

            // Overlays for controls
            VStack {
                 // Top row with Cancel ('X') button
                 HStack {
                     Button(action: {
                          // Allow cancelling
                          cameraManager.resetCaptureState() // Dismiss this view by resetting state
                     }) {
                         Image(systemName: "xmark.circle.fill")
                             .font(.title)
                             .padding()
                             .foregroundColor(.white)
                             .shadow(radius: 3)
                     }
                     .padding()
                     Spacer()
                 }

                 Spacer() // Pushes bottom controls down

                 // Bottom row with Confirm (Checkmark) button
                 HStack(spacing: 60) {
                     Spacer()
                     Button(action: {
                         // 0. Add to pending queue BEFORE dismissing/uploading
                         print("CapturedImageView: Adding image to pending queue.")
                         imageDataManager.addImageToPendingQueue()

                         // 1. Immediately dismiss the view / reset camera state
                         print("CapturedImageView: Confirm tapped. Dismissing view immediately.")
                         cameraManager.resetCaptureState()

                         //<-----CHANGE START------>
                         // 1.5 Update success timestamp HERE to trigger popup immediately
                         Task { @MainActor in // Ensure update is on main actor
                             imageDataManager.lastUploadSuccessTime = Date()
                             print("CapturedImageView: Updated lastUploadSuccessTime to trigger popup NOW.")
                         }
                         //<-----CHANGE END-------->

                         // 2. Launch the upload in a background Task
                         print("CapturedImageView: Launching upload task in background.")
                         Task(priority: .background) {
                             // Keep a copy of the image data for the background task
                             let imageToUpload = self.image

                             // Call NetworkManager's uploadImage function.
                             NetworkManager.uploadImage(imageToUpload) { result in
                                 // This completion handler still runs on the main thread when the upload finishes
                                 switch result {
                                 case .success(let urlString):
                                     // Upload finished successfully in the background
                                     print("CapturedImageView (Background Task): Upload Successful! URL: \(urlString)")
                                     //<-----CHANGE START------>
                                     // REMOVED timestamp update from here
                                     //<-----CHANGE END-------->
                                     // NOTE: Polling should eventually reflect this, manual refresh might not be needed.

                                 case .failure(let error):
                                     // Upload failed in the background
                                     print("CapturedImageView (Background Task): Upload Failed: \(error.localizedDescription)")
                                     // Optional: Log error, potentially notify user via a different mechanism if needed
                                     if case .authenticationTokenMissing = error {
                                          print("CapturedImageView (Background Task): Handling authenticationTokenMissing error.")
                                     } else if case .unauthorized = error {
                                          print("CapturedImageView (Background Task): Handling unauthorized error (session expired?).")
                                     }
                                     // Consider removing from pending queue if upload fails permanently?
                                     // This is tricky, as a retry might happen. Current logic relies on backend acknowledgement.
                                 }
                             }
                         }
                         // --- End launching background task ---
                     }) {
                         // Button content is now static - always show checkmark as we dismiss immediately
                         Image(systemName: "checkmark.circle.fill")
                             .font(.system(size: 64))
                             .foregroundColor(.white)
                             .shadow(radius: 3)
                     }
                     // Button is never disabled as action is now instantaneous
                     Spacer()
                 }
                 .padding(.bottom, 30)

                 // Removed Status Message Area - View dismisses before showing status

            } // End VStack for overlays
             // Removed animations tied to upload state variables

        } // End ZStack (main container)
         .onAppear {
              // Ensure status messages were cleared (though they are removed now)
              print("CapturedImageView: Appeared.")
         }
    }
}

// MARK: END MODIFIED FILE - Views/CapturedImageView.swift