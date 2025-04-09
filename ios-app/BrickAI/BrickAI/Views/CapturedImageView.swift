// MARK: MODIFIED FILE - Views/CapturedImageView.swift
// File: BrickAI/Views/CapturedImageView.swift
// Modified upload action to be asynchronous and immediately dismiss the view.

import SwiftUI

struct CapturedImageView: View {
    let image: UIImage // The captured image to display/upload
    // Access the shared CameraManager instance to reset state
    @StateObject private var cameraManager = CameraManager.shared

    //<-----CHANGE START------>
    // State variables for upload progress/status are no longer needed in this view
    // @State private var isUploading = false // REMOVED
    // @State private var uploadError: String? = nil // REMOVED
    // @State private var uploadSuccessURL: String? = nil // REMOVED
    //<-----CHANGE END-------->

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
                         //<-----CHANGE START------>
                         // 1. Immediately dismiss the view / reset camera state
                         print("CapturedImageView: Confirm tapped. Dismissing view immediately.")
                         cameraManager.resetCaptureState()

                         // 2. Launch the upload in a background Task
                         print("CapturedImageView: Launching upload task in background.")
                         Task(priority: .background) {
                             // Keep a copy of the image data for the background task
                             let imageToUpload = self.image

                             // Call NetworkManager's uploadImage function.
                             // The completion handler will run later, but we don't act on it here.
                             NetworkManager.uploadImage(imageToUpload) { result in
                                 // This completion handler still runs on the main thread when the upload finishes
                                 switch result {
                                 case .success(let urlString):
                                     // Upload finished successfully in the background
                                     print("CapturedImageView (Background Task): Upload Successful! URL: \(urlString)")
                                     // Optional: Could trigger a notification or update a global state/badge later
                                     // Optional: Could trigger ImageDataManager to refresh list data
                                     // Task { await ImageDataManager.shared.prepareImageData() } // Example refresh

                                 case .failure(let error):
                                     // Upload failed in the background
                                     print("CapturedImageView (Background Task): Upload Failed: \(error.localizedDescription)")
                                     // Optional: Log error, potentially notify user via a different mechanism if needed
                                     if case .authenticationTokenMissing = error {
                                          print("CapturedImageView (Background Task): Handling authenticationTokenMissing error.")
                                     } else if case .unauthorized = error {
                                          print("CapturedImageView (Background Task): Handling unauthorized error (session expired?).")
                                     }
                                 }
                             }
                         }
                         // --- End launching background task ---
                         //<-----CHANGE END-------->
                     }) {
                         //<-----CHANGE START------>
                         // Button content is now static - always show checkmark as we dismiss immediately
                         Image(systemName: "checkmark.circle.fill")
                             .font(.system(size: 64))
                             .foregroundColor(.white)
                             .shadow(radius: 3)
                         // Removed ProgressView logic:
                         /*
                         if isUploading {
                             ProgressView()
                                 .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                 .scaleEffect(2.0)
                         } else { ... }
                         */
                         //<-----CHANGE END-------->
                     }
                     //<-----CHANGE START------>
                     // Button is never disabled as action is now instantaneous
                     // .disabled(isUploading) // REMOVED
                     //<-----CHANGE END-------->
                     Spacer()
                 }
                 .padding(.bottom, 30)

                 //<-----CHANGE START------>
                 // Removed Status Message Area - View dismisses before showing status
                 /*
                 Group { ... }
                 .padding(.bottom, 10)
                 */
                 //<-----CHANGE END-------->

            } // End VStack for overlays
             //<-----CHANGE START------>
             // Removed animations tied to upload state variables
             // .animation(.easeInOut, value: uploadError)
             // .animation(.easeInOut, value: uploadSuccessURL)
             // .animation(.easeInOut, value: isUploading)
             //<-----CHANGE END-------->

        } // End ZStack (main container)
         .onAppear {
              // Ensure status messages were cleared (though they are removed now)
              print("CapturedImageView: Appeared.")
              // uploadError = nil // No longer exists
              // uploadSuccessURL = nil // No longer exists
         }
    }
}

// Previews might require providing a sample image
struct CapturedImageView_Previews: PreviewProvider {
     static var previews: some View {
         let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
          CapturedImageView(image: placeholderImage)
     }
}

// MARK: END MODIFIED FILE - Views/CapturedImageView.swift