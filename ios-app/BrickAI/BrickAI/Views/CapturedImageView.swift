import SwiftUI

struct CapturedImageView: View {
    let image: UIImage // The captured image to display/upload
    // Access the shared CameraManager instance to reset state
    @StateObject private var cameraManager = CameraManager.shared
    // We no longer need EnvironmentObject for UserManager just to pass the token

    // State variables for managing the upload process and UI feedback
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var uploadSuccessURL: String? = nil // Store returned URL on success

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Display the captured image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()

            // Overlays for controls and status messages
            VStack {
                 // Top row with Cancel ('X') button
                 HStack {
                     Button(action: {
                          // Allow cancelling only if not currently uploading
                          if !isUploading {
                               cameraManager.resetCaptureState() // Dismiss this view by resetting state
                          }
                     }) {
                         Image(systemName: "xmark")
                             .font(.title2)
                             .foregroundColor(.white)
                             .padding()
                             .background(Color.black.opacity(0.5))
                             .clipShape(Circle())
                             .shadow(radius: 3)
                     }
                     .disabled(isUploading) // Disable cancel button during upload
                     .padding() // Add padding around the button
                     Spacer() // Push button to the left
                 }

                 Spacer() // Pushes bottom controls down

                 // Bottom row with Confirm (Checkmark) button
                 HStack(spacing: 60) {
                     Spacer() // Center the button horizontally
                     Button(action: {
                         // --- Trigger Upload Action ---
                         // Set UI state to indicate uploading
                         self.isUploading = true
                         self.uploadError = nil    // Clear previous errors
                         self.uploadSuccessURL = nil // Clear previous success

                         print("CapturedImageView: Upload button tapped. Initiating upload via NetworkManager.")
                         // Call NetworkManager's uploadImage function.
                         // It now retrieves the token internally from UserManager/Keychain.
                         NetworkManager.uploadImage(self.image) { result in
                             // This completion handler runs on the main thread (handled by NetworkManager)
                             self.isUploading = false // Upload finished, update UI state

                             switch result {
                             case .success(let urlString):
                                 // --- Handle Successful Upload ---
                                 print("CapturedImageView: Upload Successful! URL: \(urlString)")
                                 self.uploadSuccessURL = urlString // Store success URL for potential display

                                 // Provide brief success feedback then dismiss the view
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                     // Check if we are still showing success before dismissing,
                                     // in case user cancelled quickly after success started showing.
                                     if self.uploadSuccessURL == urlString {
                                          cameraManager.resetCaptureState() // Dismiss view
                                     }
                                 }

                             case .failure(let error):
                                 // --- Handle Failed Upload ---
                                 print("CapturedImageView: Upload Failed: \(error.localizedDescription)")
                                 // Display the localized error description from the NetworkError enum
                                 self.uploadError = error.localizedDescription

                                 // Optionally, handle specific errors differently
                                 if case .authenticationTokenMissing = error {
                                      // Suggest user needs to re-login
                                      print("CapturedImageView: Handling authenticationTokenMissing error.")
                                      // Could trigger logout: UserManager.shared.clearUser()
                                 } else if case .unauthorized = error {
                                      // Suggest session expired
                                      print("CapturedImageView: Handling unauthorized error.")
                                      // Could trigger logout: UserManager.shared.clearUser()
                                 }
                                 // Other errors (.networkRequestFailed, .serverError, etc.) are displayed generically
                             }
                         }
                         // --- End Trigger Upload Action ---
                     }) {
                         // Button content changes based on upload state
                         if isUploading {
                             ProgressView() // Show spinner during upload
                                 .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                 .scaleEffect(2.0) // Make spinner larger
                         } else {
                             Image(systemName: "checkmark.circle.fill") // Show checkmark icon
                                 .font(.system(size: 64))
                                 .foregroundColor(.white)
                                 .shadow(radius: 3)
                         }
                     }
                     .disabled(isUploading) // Disable button while uploading
                     Spacer() // Center the button horizontally
                 }
                 .padding(.bottom, 30) // Space from bottom edge
                 
                 // --- Status Message Area ---
                 // Display error or success message dynamically
                 Group { // Group allows applying modifiers to conditional content
                      if let errorMsg = uploadError {
                          Text(errorMsg)
                              .foregroundColor(.red)
                              .padding(.horizontal)
                              .padding(.vertical, 8)
                              .background(Color.black.opacity(0.75))
                              .cornerRadius(8)
                              .transition(.opacity) // Fade in/out
                              // Optional: Allow tapping error to dismiss it
                              .onTapGesture { self.uploadError = nil }

                      } else if let successURL = uploadSuccessURL {
                          // Display success briefly (handled by dismiss timer mostly)
                           Text("Upload successful!")
                               .foregroundColor(.green)
                               .padding(.horizontal)
                               .padding(.vertical, 8)
                               .background(Color.black.opacity(0.75))
                               .cornerRadius(8)
                               .transition(.opacity) // Fade in/out
                      }
                 }
                 .padding(.bottom, 10) // Space below messages
                 // --- End Status Message Area ---

            } // End VStack for overlays
             // Apply animations to changes in state variables for smoother UI transitions
             .animation(.easeInOut, value: uploadError)
             .animation(.easeInOut, value: uploadSuccessURL)
             .animation(.easeInOut, value: isUploading)

        } // End ZStack (main container)
         .onAppear {
              // Ensure status messages are cleared when the view initially appears
              print("CapturedImageView: Appeared. Clearing status messages.")
              uploadError = nil
              uploadSuccessURL = nil
         }
    }
}

// Previews might require providing a sample image and environment objects if needed
struct CapturedImageView_Previews: PreviewProvider {
     static var previews: some View {
         // Create a placeholder UIImage for the preview
         let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
          CapturedImageView(image: placeholderImage)
              // Inject necessary environment objects or use mock managers for preview
              // .environmentObject(UserManager.shared) // No longer needed for token
              // .environmentObject(CameraManager.shared) // Already using @StateObject
     }
}
