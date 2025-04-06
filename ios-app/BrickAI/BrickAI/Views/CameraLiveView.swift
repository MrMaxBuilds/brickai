import SwiftUI
import AVFoundation

// Renamed Struct
struct CameraLiveView: UIViewRepresentable {
    let session: AVCaptureSession
     
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        // Ensure the view's frame fills the available space
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }
     
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // If the session changes, update the preview view
        if uiView.session != session {
             uiView.session = session
        }
    }
     
    // Custom UIView subclass remains the same internally
    class PreviewView: UIView {
        var session: AVCaptureSession? {
            didSet {
                guard let session = session else {
                    previewLayer.session = nil
                    return
                }
                // Check if the layer's session needs updating
                 if previewLayer.session != session {
                    previewLayer.session = session
                 }
            }
        }
         
        // The AVCaptureVideoPreviewLayer displays the camera feed.
        // Make it lazy to ensure layerClass is used.
        lazy var previewLayer: AVCaptureVideoPreviewLayer = {
             let layer = AVCaptureVideoPreviewLayer()
             layer.videoGravity = .resizeAspectFill // Fill the layer bounds
             // Set the connection's orientation later in layoutSubviews or updateOrientation
             return layer
         }()


        // Override layerClass to ensure the view's backing layer is a AVCaptureVideoPreviewLayer
        // This is often considered cleaner than adding a sublayer manually.
        // override class var layerClass: AnyClass {
        //     AVCaptureVideoPreviewLayer.self
        // }
        // Note: If using layerClass override, access the layer via `self.layer as! AVCaptureVideoPreviewLayer`.
        // The current sublayer approach is also common and works fine. Let's stick to it for consistency.

         
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupPreviewLayer()
        }
         
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupPreviewLayer()
        }
         
        private func setupPreviewLayer() {
            // If NOT using layerClass override, add the previewLayer as a sublayer
             previewLayer.videoGravity = .resizeAspectFill
             layer.addSublayer(previewLayer)
        }
         
        override func layoutSubviews() {
            super.layoutSubviews()
            // Ensure the preview layer always fills the view's bounds
            previewLayer.frame = bounds
            updateOrientation() // Update orientation whenever layout changes
        }
         
        // Update preview orientation based on interface orientation
        private func updateOrientation() {
             guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
             
             // Get current interface orientation
             // Note: Using UIDevice.current.orientation can be unreliable as it might report faceUp/faceDown.
             // It's often better to use the scene's interface orientation.
             let interfaceOrientation = window?.windowScene?.interfaceOrientation ?? .portrait // Default to portrait

             let videoOrientation: AVCaptureVideoOrientation
             switch interfaceOrientation {
             case .portrait:
                 videoOrientation = .portrait
             case .landscapeLeft:
                 videoOrientation = .landscapeLeft // Map directly
             case .landscapeRight:
                 videoOrientation = .landscapeRight // Map directly
             case .portraitUpsideDown:
                 videoOrientation = .portraitUpsideDown
             case .unknown:
                  videoOrientation = .portrait // Fallback
             @unknown default:
                 videoOrientation = .portrait // Fallback
             }
             
             if connection.videoOrientation != videoOrientation {
                  connection.videoOrientation = videoOrientation
             }
        }
    }
}
