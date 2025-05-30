// MARK: MODIFIED FILE - Views/CapturedImageView.swift
// File: BrickAI/Views/CapturedImageView.swift
// Modified upload action to be asynchronous and immediately dismiss the view.
// Added call to ImageDataManager to enqueue pending upload.
// Update ImageDataManager's lastUploadSuccessTime on successful upload.
// <-----CHANGE START------>
// Moved update of lastUploadSuccessTime to trigger immediately before upload starts.
// Added image resizing to reduce file size before upload.
// <-----CHANGE END-------->


import SwiftUI

struct CapturedImageView: View {
    let image: UIImage // The captured image to display/upload
    let isSelfie: Bool // Added to know if the image was from front camera
    let isFromCameraRoll: Bool // Added to know if the image was from camera roll

    @StateObject private var cameraManager = CameraManager.shared
    @EnvironmentObject var imageDataManager: ImageDataManager
    @EnvironmentObject var userManager: UserManager

    // State variables for credit check and navigation to PaymentsView
    @State private var showInsufficientCreditsAlert = false
    @State private var presentPaymentsView = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Display the captured image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: isFromCameraRoll ? .fit : .fill)
                .scaleEffect(x: (!isFromCameraRoll && isSelfie) ? -1 : 1, y: 1)
                .ignoresSafeArea()

            // Overlays for controls
            VStack {
                 // Top row with Cancel ('X') button
                 HStack {
                    Spacer()
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
                    .padding() // Keep padding for the button itself
                    Spacer().frame(width: 300)
                    Spacer() // This Spacer pushes the button to the left
                 }

                 Spacer() // Pushes bottom controls down

                 // Bottom row with Confirm (Checkmark) button
                 HStack(spacing: 60) {
                     Spacer()
                     Button(action: handleConfirmAction) {
                         Text("Create!")
                             .font(.system(size: 24, weight: .bold))
                             .foregroundColor(.white)
                             .padding(.horizontal, 40)
                             .padding(.vertical, 15)
                             .background(Color.blue)
                             .cornerRadius(30)
                             .shadow(radius: 5)
                     }
                     // Button is never disabled as action is now instantaneous
                     Spacer()
                 }
                 .padding(.bottom, 30)

                 // Removed Status Message Area - View dismisses before showing status

            }
        }
        .onAppear {
            print("CapturedImageView: Appeared.")
        }
        // Alert for insufficient credits
        .alert("Insufficient Credits", isPresented: $showInsufficientCreditsAlert) {
            Button("Purchase Credits") {
                self.presentPaymentsView = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You don't have enough credits to upload an image. Please purchase more to continue.")
        }
        // Sheet to present PaymentsView
        .sheet(isPresented: $presentPaymentsView) {
            // Ensure PaymentsView gets its necessary environment objects if any
            // (it will inherit from CapturedImageView's environment)
            PaymentsView()
        }
    }
    
    // MARK: - Action Handlers
    private func handleConfirmAction() {
        // Check for sufficient credits BEFORE any other action
        guard let credits = userManager.userCredits, credits > 0 else {
            print("CapturedImageView: Insufficient credits (\(userManager.userCredits ?? 0)). Showing alert.")
            self.showInsufficientCreditsAlert = true
            return // Stop further processing
        }
        
        // If credits are sufficient, proceed with upload logic:

        // 0. Add to pending queue BEFORE dismissing/uploading
        print("CapturedImageView: Adding image to pending queue.")
        imageDataManager.addImageToPendingQueue()

        // 1. Immediately dismiss the view / reset camera state
        print("CapturedImageView: Confirm tapped. Dismissing view immediately.")
        cameraManager.resetCaptureState()

        // 1.5 Update success timestamp HERE to trigger popup immediately
        Task { @MainActor in // Ensure update is on main actor
            imageDataManager.lastUploadSuccessTime = Date()
            print("CapturedImageView: Updated lastUploadSuccessTime to trigger popup NOW.")
        }

        // 2. Launch the upload in a background Task
        print("CapturedImageView: Launching upload task in background.")
        Task(priority: .background) {
            // Keep a copy of the image data for the background task
            let imageToUpload = self.image
            
            // Resize the image before uploading to reduce file size
            let resizedImage = resizeImage(imageToUpload)
            print("CapturedImageView: Resized image for upload. Original size: \(imageToUpload.size), New size: \(resizedImage.size)")

            // Call NetworkManager's uploadImage function.
            NetworkManager.uploadImage(resizedImage) { result in
                // This completion handler still runs on the main thread when the upload finishes
                switch result {
                case .success(let urlString):
                    // Upload finished successfully in the background
                    print("CapturedImageView (Background Task): Upload Successful! URL: \(urlString)")
                    // REMOVED timestamp update from here
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
    }

    // Resize and compress the image to reduce file size
    private func resizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200 // Maximum width/height (adjust as needed)
        let compressionQuality: CGFloat = 0.7 // JPEG compression quality (0.0-1.0)
        
        // Calculate scaling factor to maintain aspect ratio
        let originalSize = image.size
        var newSize = originalSize
        
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let widthRatio = maxDimension / originalSize.width
            let heightRatio = maxDimension / originalSize.height
            let ratio = min(widthRatio, heightRatio)
            
            newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        } else {
            // No resizing needed if already small enough
            return compressImage(image, compressionQuality: compressionQuality)
        }
        
        // Render the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        // Apply JPEG compression to the resized image
        return compressImage(resizedImage, compressionQuality: compressionQuality)
    }
    
    // Compress image using JPEG compression
    private func compressImage(_ image: UIImage, compressionQuality: CGFloat) -> UIImage {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality),
              let compressedImage = UIImage(data: imageData) else {
            return image // Return original if compression fails
        }
        return compressedImage
    }
}

// MARK: END MODIFIED FILE - Views/CapturedImageView.swift
