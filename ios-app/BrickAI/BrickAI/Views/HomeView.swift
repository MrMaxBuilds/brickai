import SwiftUI
import AVFoundation

struct HomeView: View {
    // Access shared managers
    // Use @StateObject for CameraManager as this view manages its lifecycle (start/stop)
    @StateObject private var cameraManager = CameraManager.shared
    // Use @EnvironmentObject for UserManager if it's provided higher up in the hierarchy
    // If HomeView is the root after login, UserManager might also be @StateObject here.
    // Assuming it's provided via environment:
    @EnvironmentObject var userManager: UserManager

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
                               // Inject environment objects if CapturedImageView needs them
                               // .environmentObject(userManager) // Example if needed
                               .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity)) // Slide in
                      } else {
                           // --- Show Camera Preview and Controls ---
                          CameraLiveView(session: cameraManager.session)
                               .ignoresSafeArea()
                               .transition(.identity) // No transition for the preview itself when appearing
                               .overlay(alignment: .bottom) {
                                     // --- Capture Button ---
                                    Button(action: cameraManager.capturePhoto) { // Directly call capture method
                                         // Standard capture button UI
                                         ZStack {
                                             Circle().fill(.white).frame(width: 65, height: 65)
                                             Circle().stroke(.white, lineWidth: 2).frame(width: 75, height: 75)
                                         }
                                         .shadow(radius: 5)
                                    }
                                    .padding(.bottom, 40) // Adjust spacing from bottom
                               }
                               .overlay(alignment: .topTrailing) {
                                    // --- Settings Button ---
                                     NavigationLink(destination: SettingsView()) { // Assuming SettingsView exists
                                          Image(systemName: "gear")
                                               .font(.title2) // Slightly smaller than title
                                               .foregroundColor(.white)
                                               .padding()
                                               .background(Color.black.opacity(0.5))
                                               .clipShape(Circle())
                                               .shadow(radius: 3)
                                     }
                                     .padding([.top, .trailing]) // Add padding
                               }
                               .overlay(alignment: .bottomTrailing) { // Image List Button remains
                                    NavigationLink(destination: ImageListView()) { Image(systemName: "photo.stack").font(.title2).foregroundColor(.white).padding().background(Color.black.opacity(0.5)).clipShape(Circle()) }
                                        .padding(.bottom, 40).padding(.trailing)
                                }
                      } // End else (show camera preview)
                 } else {
                      // --- Show No Permission View ---
                       NoAccessView(onRequestPermission: cameraManager.requestCameraPermission) // Pass request func
                       .transition(.opacity) // Fade in no access view
                 } // End if permissionGranted

             } // End ZStack
             // --- View Modifiers ---
              .navigationBarHidden(true) // Typically hide nav bar for camera view
              .statusBar(hidden: true) // Often hide status bar too
              .onAppear {
                  print("HomeView: Appeared.")
                  // Check permission status when view appears
                  cameraManager.checkCameraPermission()
                  // Start session only if permission is granted AND no image is currently captured
                  if cameraManager.isPermissionGranted && cameraManager.capturedImage == nil {
                       cameraManager.startSession()
                  }
              }
              .onDisappear {
                   print("HomeView: Disappeared.")
                   // Always stop session when the view disappears entirely
                   cameraManager.stopSession()
              }
              .onChange(of: cameraManager.capturedImage) { oldImage, newImage in
                  // Stop session when an image IS captured, start when it's cleared (if permitted)
                   if newImage != nil {
                       print("HomeView: Image captured, stopping session.")
                       cameraManager.stopSession()
                   } else {
                       // Image was cleared (newImage is nil)
                       print("HomeView: Captured image cleared.")
                       if cameraManager.isPermissionGranted {
                            print("HomeView: Starting session after image clear.")
                            cameraManager.startSession()
                       }
                   }
              }
              .onChange(of: cameraManager.isPermissionGranted) { oldPermission, newPermission in
                   // Handle permission changes while the view is visible
                   if newPermission {
                        // Permission was just granted, start session if no image is captured
                        if cameraManager.capturedImage == nil && !cameraManager.session.isRunning {
                             print("HomeView: Permission granted, starting session.")
                             cameraManager.startSession()
                        }
                   } else {
                        // Permission was just revoked or denied
                         print("HomeView: Permission revoked/denied, stopping session.")
                        cameraManager.stopSession()
                   }
              }
               // Recheck permission status when app comes to foreground
              .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                   print("HomeView: App will enter foreground, rechecking permission.")
                   cameraManager.checkCameraPermission()
              }
         } // End NavigationStack
    } // End body
}

// --- NoAccessView (Updated to accept action) ---
struct NoAccessView: View {
     var onRequestPermission: () -> Void // Callback to request permission

     var body: some View {
         VStack(spacing: 15) { // Add spacing
             Spacer() // Push content to center
             Image(systemName: "camera.fill") // Use filled icon
                 .font(.system(size: 60))
                 .foregroundColor(.secondary)
                 .padding(.bottom, 10)

             Text("Camera Access Required")
                 .font(.title2)
                 .fontWeight(.semibold)

             Text("Enable camera access in Settings to capture photos.")
                 .font(.subheadline)
                 .foregroundColor(.gray)
                 .multilineTextAlignment(.center)
                 .padding(.horizontal, 40) // Add horizontal padding for text wrapping

             // Button to request permission directly first
             Button("Allow Camera Access", action: onRequestPermission)
                  .padding(.vertical, 10)
                  .padding(.horizontal, 20)
                  .background(Color.blue)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                  .padding(.top)


             // Button to open App Settings as a fallback
             Button("Open App Settings") {
                 if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                    UIApplication.shared.canOpenURL(settingsUrl) {
                     UIApplication.shared.open(settingsUrl)
                 }
             }
             .font(.footnote) // Make settings link less prominent
             .padding(.top, 5)

             Spacer() // Push content to center
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
         .background(Color(.systemBackground)) // Use system background color
     }
}

// --- Preview ---
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            // Provide mock/shared managers for the preview to function
            .environmentObject(UserManager.shared)
            // CameraManager uses @StateObject internally now
    }
}
