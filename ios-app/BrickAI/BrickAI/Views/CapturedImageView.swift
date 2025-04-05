import SwiftUI

struct CapturedImageView: View {
    let image: UIImage
    @StateObject private var cameraManager = CameraManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        cameraManager.resetCaptureState()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
                HStack(spacing: 60) {
                    Spacer()
                    Button(action: {
                        cameraManager.resetCaptureState()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.bottom, 30)
            }
        }
    }
}
