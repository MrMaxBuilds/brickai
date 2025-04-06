import SwiftUI

struct CapturedImageView: View {
    let image: UIImage
    @StateObject private var cameraManager = CameraManager.shared
    // States remain in the View as they control the UI
    @State private var isUploading = false
    @State private var uploadError: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()

            VStack {
                // Top row with X button
                HStack {
                    Button(action: {
                        // Only allow cancel if not uploading
                        if !isUploading {
                            cameraManager.resetCaptureState()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(isUploading) // Good practice to disable if needed
                    .padding()
                    Spacer()
                }

                Spacer()

                // Bottom row with Checkmark button
                HStack(spacing: 60) {
                    Spacer()
                    Button(action: {
                        // Set uploading state and initiate upload via NetworkManager
                        self.isUploading = true
                        self.uploadError = nil // Clear previous errors

                        NetworkManager.uploadImage(self.image) { result in
                            // This completion handler is called on the main thread by NetworkManager
                            self.isUploading = false // Upload finished

                            switch result {
                            case .success:
                                print("Upload Successful!")
                                // Reset camera state (dismisses this view)
                                self.cameraManager.resetCaptureState()

                            case .failure(let error):
                                print("Upload Failed: \(error.localizedDescription)")
                                // Set the error message state to display it
                                self.uploadError = error.localizedDescription
                            }
                        }
                    }) {
                        // Show progress indicator while uploading
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2.0)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isUploading) // Disable button during upload
                    Spacer()
                }
                .padding(.bottom, 30)

                // Optional: Display upload error message
                if let errorMsg = uploadError {
                    Text(errorMsg) // Display the localized error description
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 10)
                        .transition(.opacity) // Add a little fade effect
                        // Clear error after a delay
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                if self.uploadError == errorMsg { // Only clear if it's the same error
                                    self.uploadError = nil
                                }
                            }
                        }
                }
            } // End VStack
            .animation(.easeInOut, value: uploadError) // Animate error appearance/disappearance
            .animation(.easeInOut, value: isUploading) // Animate progress view transition

        } // End ZStack
    }
}

// Reminder: Make sure 'APIEndpointURL' is correctly set in your Info.plist
