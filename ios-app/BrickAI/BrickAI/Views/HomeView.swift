// MARK: MODIFIED FILE - Views/HomeView.swift
// Changed settings button icon to person.circle.fill and made it more unassuming.
// Added camera switch button

import SwiftUI
import AVFoundation

struct HomeView: View {
    // Access shared managers
    @StateObject private var cameraManager = CameraManager.shared
    @EnvironmentObject var userManager: UserManager // Assuming provided by parent (e.g., LoginView)

    var body: some View {
         // Use NavigationStack for modern navigation features
         NavigationStack {
             ZStack {
                 // --- Main Content Area ---
                 if cameraManager.isPermissionGranted {
                      // --- Camera Granted Flow ---
                      if let capturedImage = cameraManager.capturedImage {
                          // --- Show Captured Image View ---
                           CapturedImageView(image: capturedImage)
                               .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity))
                      } else {
                           // --- Show Camera Preview and Controls ---
                          CameraLiveView(session: cameraManager.session)
                               .ignoresSafeArea()
                               .transition(.identity)
                               .overlay(alignment: .bottom) { // Capture Button Overlay
                                     Button(action: cameraManager.capturePhoto) {
                                         ZStack {
                                             Circle().fill(.white).frame(width: 65, height: 65)
                                             Circle().stroke(.white, lineWidth: 2).frame(width: 75, height: 75)
                                         }
                                         .shadow(radius: 5)
                                    }
                                    .padding(.bottom, 40)
                               }
                               // <<< MODIFIED: Settings Button Overlay >>> // This comment is preserved
                               .overlay(alignment: .topTrailing) {
                                   NavigationLink(destination: UserInfoView()) {
                                          Image(systemName: "person.circle.fill") // User icon
                                               .font(.title) // Make slightly larger for tap area without background
                                               .foregroundColor(.white.opacity(0.8)) // Slightly transparent white
                                     }
                                     // Existing padding keeps it in the corner, adjusted slightly
                                     .padding([.top, .trailing], 16)
                               }
                               //<-----CHANGE START------>
                               // <<< ADDED: Camera Switch Button Overlay >>>
                               .overlay(alignment: .bottomLeading) {
                                    Button(action: cameraManager.switchCamera) {
                                         Image(systemName: "arrow.triangle.2.circlepath.camera") // Icon for switching camera
                                             .font(.title2) // Slightly smaller than capture/settings
                                             .foregroundColor(.white)
                                             .padding() // Add padding for tap area
                                             .background(Color.black.opacity(0.5)) // Consistent background
                                             .clipShape(Circle()) // Circular shape
                                    }
                                    .padding(.bottom, 40) // Align vertically with image list button
                                    .padding(.leading) // Padding from the left edge
                               }
                               //<-----CHANGE END-------->
                               .overlay(alignment: .bottomTrailing) { // Image List Button Overlay (Unchanged)
                                    NavigationLink(destination: ImageListView()) { Image(systemName: "photo.stack").font(.title2).foregroundColor(.white).padding().background(Color.black.opacity(0.5)).clipShape(Circle()) }
                                        .padding(.bottom, 40).padding(.trailing)
                                }
                      } // End else (show camera preview)
                 } else {
                      // --- Show No Permission View ---
                       NoAccessView(onRequestPermission: cameraManager.requestCameraPermission)
                       .transition(.opacity)
                 } // End if permissionGranted

             } // End ZStack
             // --- View Modifiers (Unchanged) ---
              .navigationBarHidden(true)
              .statusBar(hidden: true)
              .onAppear {
                  print("HomeView: Appeared.")
                  cameraManager.checkCameraPermission()
                  if cameraManager.isPermissionGranted && cameraManager.capturedImage == nil {
                       cameraManager.startSession()
                  }
              }
              .onDisappear {
                   print("HomeView: Disappeared.")
                   cameraManager.stopSession()
              }
              .onChange(of: cameraManager.capturedImage) { oldImage, newImage in
                   if newImage != nil {
                       print("HomeView: Image captured, stopping session.")
                       cameraManager.stopSession()
                   } else {
                       print("HomeView: Captured image cleared.")
                       if cameraManager.isPermissionGranted {
                            print("HomeView: Starting session after image clear.")
                            cameraManager.startSession()
                       }
                   }
              }
              .onChange(of: cameraManager.isPermissionGranted) { oldPermission, newPermission in
                   if newPermission {
                        if cameraManager.capturedImage == nil && !cameraManager.session.isRunning {
                             print("HomeView: Permission granted, starting session.")
                             cameraManager.startSession()
                        }
                   } else {
                         print("HomeView: Permission revoked/denied, stopping session.")
                        cameraManager.stopSession()
                   }
              }
              .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                   print("HomeView: App will enter foreground, rechecking permission.")
                   cameraManager.checkCameraPermission()
              }
         } // End NavigationStack
    } // End body
}

// --- NoAccessView (Unchanged) ---
struct NoAccessView: View {
     var onRequestPermission: () -> Void

     var body: some View {
         VStack(spacing: 15) {
             Spacer()
             Image(systemName: "camera.fill")
                 .font(.system(size: 60)).foregroundColor(.secondary).padding(.bottom, 10)
             Text("Camera Access Required").font(.title2).fontWeight(.semibold)
             Text("Enable camera access in Settings to capture photos.")
                 .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 40)
             Button("Allow Camera Access", action: onRequestPermission)
                  .padding(.vertical, 10).padding(.horizontal, 20).background(Color.blue).foregroundColor(.white).cornerRadius(8).padding(.top)
             Button("Open App Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }}
                 .font(.footnote).padding(.top, 5)
             Spacer()
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .background(Color(.systemBackground))
     }
}

// --- Preview (Unchanged) ---
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(UserManager.shared) // Make sure UserManager is available for preview
    }
}

// MARK: END MODIFIED FILE - Views/HomeView.swift
