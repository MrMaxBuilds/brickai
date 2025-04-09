import Foundation
import AVFoundation
import UIKit // Needed for UIImage
import Combine // Needed for ObservableObject

class CameraManager: ObservableObject {
    static let shared = CameraManager()
    let session = AVCaptureSession()

    // --- Published Properties ---
    @Published var capturedImage: UIImage? // Holds the image after capture
    @Published private(set) var isPermissionGranted: Bool = false // Camera permission state
    @Published private(set) var currentCameraPosition: AVCaptureDevice.Position = .back

    // --- Private Properties ---
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    // Add a delegate object to handle photo capture callbacks
    private var photoCaptureDelegate: PhotoCaptureProcessor?

    // --- Initialization ---
    private init() {
        print("CameraManager: Initializing...")
        checkCameraPermission() // Check initial permission status
        // Configure only if permission is initially granted, or defer until granted?
        // Let's configure regardless, session won't work without permission anyway.
        configureSession()
    }

    // --- Permission Handling ---
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            print("CameraManager: Permission already granted.")
            self.isPermissionGranted = true
        case .notDetermined: // The user has not yet been asked for camera access.
            print("CameraManager: Permission not determined yet.")
            self.isPermissionGranted = false
            // Don't request here automatically, let UI trigger request if needed
        case .denied: // The user has previously denied access.
             print("CameraManager: Permission denied previously.")
            self.isPermissionGranted = false
        case .restricted: // The user can't grant access due to restrictions.
             print("CameraManager: Permission restricted.")
            self.isPermissionGranted = false
        @unknown default:
             print("CameraManager: Unknown permission status.")
            self.isPermissionGranted = false
        }
    }

    func requestCameraPermission() {
         // Request on background thread? Apple docs don't specify, but UI updates should be main.
         AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
             DispatchQueue.main.async { // Update state on main thread
                 self?.isPermissionGranted = granted
                 if granted {
                     print("CameraManager: Permission granted by user.")
                     // Optionally start session immediately if configured and needed?
                     // self?.startSession()
                 } else {
                     print("CameraManager: Permission denied by user.")
                 }
             }
         }
    }

    // --- Session Configuration ---
    func configureSession() {
        // Should only run if session isn't already configured? Add check?
        guard session.inputs.isEmpty && session.outputs.isEmpty else {
             print("CameraManager: Session already configured.")
             return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo // Use high quality preset

        // Find video device based on the current desired position (defaults to back)
        //<-----CHANGE START------>
        // Corrected the guard statement's else block
        var deviceToUse: AVCaptureDevice? = nil
        if let primaryDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) {
             deviceToUse = primaryDevice
        } else {
             print("CameraManager Error: Failed to find primary camera for position \(currentCameraPosition). Attempting fallback.")
             let fallbackPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
             if let fallbackDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: fallbackPosition) {
                  print("CameraManager: Using fallback camera position \(fallbackPosition)")
                  deviceToUse = fallbackDevice
                  currentCameraPosition = fallbackPosition // Update state if using fallback
             } else {
                  print("CameraManager Error: Failed to find fallback camera either.")
                  session.commitConfiguration() // Commit before returning
                  return // Exit scope if no device found
             }
        }

        // Ensure we actually have a device before proceeding
        guard let videoDevice = deviceToUse else {
             print("CameraManager Error: No suitable video device found after primary and fallback checks.")
             session.commitConfiguration() // Commit before returning
             return // Exit scope if device is still nil (shouldn't happen logically here but safer)
        }
        //<-----CHANGE END-------->

        // Create video input
        do {
             videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("CameraManager Error: Could not create video device input: \(error)")
            session.commitConfiguration()
            return
        }

        // Add video input
        if let videoInput = videoDeviceInput, session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            print("CameraManager Error: Could not add video device input to session.")
            session.commitConfiguration()
            return
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            // Configure other settings like photo quality, stabilization if needed
        } else {
             print("CameraManager Error: Could not add photo output to session.")
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
        print("CameraManager: Session configured successfully for position \(currentCameraPosition).")
    }

    // --- Session Control ---
    // Start the session if permission is granted and it's not already running
    func startSession() {
        guard isPermissionGranted else {
            print("CameraManager: Cannot start session, permission not granted.")
            return
        }
        // Run on a background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                print("CameraManager: Session started running.")
            } else {
                 // print("CameraManager: Session already running.") // Less noisy log
            }
        }
    }

    // Stop the session if it's running
    func stopSession() {
        // Ensure stop is on background thread if start was
         DispatchQueue.global(qos: .userInitiated).async { [weak self] in
               guard let self = self else { return }
               if self.session.isRunning {
                    self.session.stopRunning()
                    print("CameraManager: Session stopped running.")
               } else {
                   // print("CameraManager: Session already stopped.") // Less noisy log
               }
         }
    }

    // --- Photo Capture ---
    func capturePhoto() {
         guard session.isRunning else {
              print("CameraManager Error: Cannot capture photo, session is not running.")
              // Maybe try starting session? Or just return?
              return
         }
         guard isPermissionGranted else {
             print("CameraManager Error: Cannot capture photo, permission denied.")
             return
         }

         print("CameraManager: Initiating photo capture.")
         let settings = AVCapturePhotoSettings()
         // Configure settings (flash, quality, etc.) if needed
         // settings.flashMode = .auto // Example

         // Create a delegate object instance for this capture request
         // This delegate will handle receiving the photo data
         photoCaptureDelegate = PhotoCaptureProcessor { [weak self] image in
              // This completion block is called by the delegate when processing is done
              DispatchQueue.main.async { // Update published property on main thread
                  self?.capturedImage = image
                  print("CameraManager: Photo captured and processed. Updated published property.")
                  // Stop session after capture? Yes, typically done by HomeView's onChange.
                  // self?.stopSession()
              }
              // Release the delegate reference once capture is complete
               self?.photoCaptureDelegate = nil
         }

         // Initiate the capture
         photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate!)
    }

    // --- State Reset ---
    // Call this from CapturedImageView (or HomeView) to dismiss the captured image view
    func resetCaptureState() {
        DispatchQueue.main.async { // Ensure UI updates on main thread
            self.capturedImage = nil
            print("CameraManager: Capture state reset (capturedImage set to nil).")
            // Should the session restart here? Let HomeView's onChange handle it.
        }
    }

    // --- Camera Switching ---
    func switchCamera() {
         guard session.isRunning else {
              print("CameraManager: Cannot switch camera, session is not running.")
              return
         }
         guard let currentInput = self.videoDeviceInput else {
              print("CameraManager: Cannot switch camera, current video input is nil.")
              return
         }

         // Determine the desired position
         let desiredPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
         print("CameraManager: Attempting to switch camera to \(desiredPosition).")

         // Find the new device
         guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: desiredPosition) else {
              print("CameraManager Error: Failed to find camera for position \(desiredPosition).")
              return
         }

         // Create new input
         let newVideoInput: AVCaptureDeviceInput
         do {
              newVideoInput = try AVCaptureDeviceInput(device: newDevice)
         } catch {
              print("CameraManager Error: Could not create video input for \(desiredPosition): \(error)")
              return
         }

         // Perform the switch on the session (needs configuration block)
         session.beginConfiguration()

         // Remove the old input
         session.removeInput(currentInput)

         // Add the new input
         if session.canAddInput(newVideoInput) {
              session.addInput(newVideoInput)
              self.videoDeviceInput = newVideoInput // Update the stored input reference
              // Update the published state on the main thread
              DispatchQueue.main.async {
                   self.currentCameraPosition = desiredPosition
              }
              print("CameraManager: Successfully switched camera to \(desiredPosition).")
         } else {
              print("CameraManager Error: Could not add new video input for \(desiredPosition). Re-adding old input.")
              // Attempt to re-add the old input if adding the new one failed
              if session.canAddInput(currentInput) {
                   session.addInput(currentInput)
              }
              // Don't update state if switch failed
         }

         // Commit the configuration changes
         session.commitConfiguration()
    }
}

// --- AVCapturePhotoCaptureDelegate Implementation ---
// Create a separate class to handle the delegate callbacks cleanly.
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    // Completion handler to call back with the processed image
    private var completionHandler: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completionHandler = completion
        print("PhotoCaptureProcessor: Initialized.")
    }

    // This delegate method is called when the photo processing is complete
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("PhotoCaptureProcessor: didFinishProcessingPhoto called.")
        if let error = error {
            print("PhotoCaptureProcessor Error: Error capturing photo: \(error.localizedDescription)")
            completionHandler(nil)
            return
        }

        // Get image data
        guard let imageData = photo.fileDataRepresentation() else {
            print("PhotoCaptureProcessor Error: Could not get image data representation.")
            completionHandler(nil)
            return
        }

        // Create UIImage
        guard let capturedImage = UIImage(data: imageData) else {
             print("PhotoCaptureProcessor Error: Could not create UIImage from data.")
             completionHandler(nil)
             return
        }

        print("PhotoCaptureProcessor: Successfully processed photo into UIImage.")
        // Call the completion handler with the successful image
        completionHandler(capturedImage)
    }

     // You might implement other delegate methods if needed (e.g., willBeginCapture, didFinishCapture)
     func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
         print("PhotoCaptureProcessor: willBeginCapture...")
         // E.g., Trigger shutter sound or visual feedback
     }

     func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
         if let error = error {
             print("PhotoCaptureProcessor: didFinishCapture with error: \(error)")
         } else {
             print("PhotoCaptureProcessor: didFinishCapture successfully.")
             // E.g., Stop shutter sound/visual feedback
         }
     }
}
