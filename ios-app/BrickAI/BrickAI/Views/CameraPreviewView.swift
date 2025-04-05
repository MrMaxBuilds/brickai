import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    
    // Custom UIView subclass to handle orientation
    class PreviewView: UIView {
        var session: AVCaptureSession? {
            didSet {
                if let session = session {
                    previewLayer.session = session
                }
            }
        }
        
        private let previewLayer = AVCaptureVideoPreviewLayer()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupPreviewLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupPreviewLayer()
        }
        
        private func setupPreviewLayer() {
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            updateOrientation()
        }
        
        // Update preview orientation based on device orientation
        private func updateOrientation() {
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                let orientation = UIDevice.current.orientation
                switch orientation {
                case .portrait:
                    connection.videoOrientation = .portrait
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeRight
                case .landscapeRight:
                    connection.videoOrientation = .landscapeLeft
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                default:
                    connection.videoOrientation = .portrait
                }
            }
        }
    }
}
