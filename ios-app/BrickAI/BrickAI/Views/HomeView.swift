// MARK: MODIFIED FILE - Views/HomeView.swift
// Changed settings button icon to person.circle.fill and made it more unassuming.
// Added camera switch button
// Added success popup notification triggered by ImageDataManager.
// <-----CHANGE START------>
// Removed internal UploadSuccessPopup definition and use UploadSuccessPopupView from separate file.
// <-----CHANGE END-------->


import SwiftUI
import AVFoundation

struct HomeView: View {
    // Access shared managers
    @StateObject private var cameraManager = CameraManager.shared
    @EnvironmentObject var userManager: UserManager // Assuming provided by parent (e.g., LoginView)
    // Access ImageDataManager to monitor upload success
    @EnvironmentObject var imageDataManager: ImageDataManager
    // State to control the success popup visibility
    @State private var showSuccessPopup = false
    // Store the task responsible for hiding the popup to allow cancellation
    @State private var hidePopupTask: Task<Void, Never>? = nil


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
                               .environmentObject(imageDataManager) // Pass manager down
                               .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity))
                      } else {
                           // --- Show Camera Preview and Controls ---
                           // Group the CameraLiveView and its specific overlays
                           ZStack {
                               CameraLiveView(session: cameraManager.session)
                                    .ignoresSafeArea()
                                    .transition(.identity)

                               // Overlays directly related to CameraLiveView
                               VStack {
                                   // Top Spacer (pushes content down)
                                   Spacer()

                                   // Bottom Controls Row
                                   HStack {
                                       // Camera Switch Button
                                       Button(action: cameraManager.switchCamera) {
                                           Image(systemName: "arrow.triangle.2.circlepath.camera")
                                               .font(.title2)
                                               .foregroundColor(.white)
                                               .padding()
                                               .background(Color.black.opacity(0.5))
                                               .clipShape(Circle())
                                       }
                                       .padding(.leading)

                                       Spacer() // Center capture button

                                       // Capture Button
                                       Button(action: cameraManager.capturePhoto) {
                                            ZStack {
                                                Circle().fill(.white).frame(width: 65, height: 65)
                                                Circle().stroke(.white, lineWidth: 2).frame(width: 75, height: 75)
                                            }
                                            .shadow(radius: 5)
                                       }

                                       Spacer() // Right align list button

                                       // Image List Button
                                       NavigationLink(destination: ImageListView()) {
                                            Image(systemName: "photo.stack")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .padding()
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Circle())
                                        }
                                        .padding(.trailing)

                                   } // End HStack for bottom controls
                                   .padding(.bottom, 40) // Padding from bottom edge

                               } // End VStack for bottom controls layout

                               // --- Upload Success Popup Overlay ---
                               // Added overlay within the ZStack containing CameraLiveView
                               VStack {
                                    if showSuccessPopup {
                                        //<-----CHANGE START------>
                                        // Use the new view from the separate file
                                        UploadSuccessPopupView()
                                        //<-----CHANGE END-------->
                                             .transition(.move(edge: .top).combined(with: .opacity))
                                             .onAppear {
                                                 // Cancel any existing hide task before starting a new one
                                                 hidePopupTask?.cancel()
                                                 // Schedule task to hide popup after delay
                                                 hidePopupTask = Task {
                                                      do {
                                                          // Wait for 2 seconds (adjust duration if needed)
                                                          try await Task.sleep(nanoseconds: 2_000_000_000)
                                                          // Hide the popup if the task wasn't cancelled
                                                          withAnimation {
                                                              showSuccessPopup = false
                                                          }
                                                          print("HomeView: Hiding success popup after delay.")
                                                      } catch {
                                                          // Handle cancellation (e.g., if view disappears or another upload happens quickly)
                                                          print("HomeView: Hide popup task cancelled.")
                                                      }
                                                 }
                                             }
                                    }
                                    Spacer() // Pushes popup to the top
                               }
                               .padding(.top, 20) // Padding from the very top safe area edge
                               // Use default animation for showing/hiding container, new view has internal animation
                               .animation(.default, value: showSuccessPopup)


                           } // End ZStack for CameraLiveView + overlays

                           // --- Settings Button Overlay (applied to the outer ZStack) ---
                           // Needs to be outside the inner ZStack if it should always be visible
                           // Or inside if it should only appear with CameraLiveView
                           // Let's keep it outside for consistency.
                            .overlay(alignment: .topTrailing) {
                                NavigationLink(destination: UserInfoView()) {
                                       Image(systemName: "person.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.white.opacity(0.8))
                                  }
                                  .padding([.top, .trailing], 16)
                            }


                      } // End else (show camera preview)
                 } else {
                      // --- Show No Permission View ---
                       NoAccessView(onRequestPermission: cameraManager.requestCameraPermission)
                       .transition(.opacity)
                 } // End if permissionGranted

             } // End ZStack
             // --- View Modifiers ---
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
                   // Cancel hide popup task if view disappears
                   hidePopupTask?.cancel()
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
              // --- Listener for Upload Success ---
              .onChange(of: imageDataManager.lastUploadSuccessTime) { _, newValue in
                   // Trigger popup only if the new value is non-nil
                   // (We don't need to compare old/new, just react to the latest success)
                   if newValue != nil {
                       print("HomeView: Detected new upload success time. Showing popup.")
                       // Use default animation here, the view inside animates itself
                       withAnimation {
                           showSuccessPopup = true
                       }
                       // The .onAppear modifier of the popup itself handles the timer to hide it.
                   }
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


// MARK: END MODIFIED FILE - Views/HomeView.swift
