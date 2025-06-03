// MARK: MODIFIED FILE - Views/HomeView.swift
// Changed settings button icon to person.circle.fill and made it more unassuming.
// Added camera switch button
// Added success popup notification triggered by ImageDataManager.
// Removed internal UploadSuccessPopup definition and use UploadSuccessPopupView from separate file.
// <-----CHANGE START------>
// Added notification badge to Image List button showing actively processing count.
// Added Usages/Payments Icon Button to top-left.
// <-----CHANGE END-------->


import SwiftUI
import AVFoundation
import PhotosUI

struct HomeView: View {
    // Access shared managers
    @StateObject private var cameraManager = CameraManager.shared
    @EnvironmentObject var userManager: UserManager // Assuming provided by parent (e.g., LoginView)
    // Access ImageDataManager to monitor upload success and processing count
    @EnvironmentObject var imageDataManager: ImageDataManager
    // State to control the success popup visibility
    @State private var showSuccessPopup = false
    // Store the task responsible for hiding the popup to allow cancellation
    @State private var hidePopupTask: Task<Void, Never>? = nil
    // State to manage photo selection from library
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showPaymentsSheet = false // <<< ADDED: State for presenting PaymentsView as a sheet
    @State private var isCurrentImageFromCameraRoll: Bool = false // ADDED: To track image source


    var body: some View {
         // Use NavigationStack for modern navigation features
         NavigationStack {
             ZStack {
                 // --- Main Content Area ---
                 if cameraManager.isPermissionGranted {
                      // --- Camera Granted Flow ---
                      if let capturedImage = cameraManager.capturedImage {
                          // --- Show Captured Image View ---
                           CapturedImageView(image: capturedImage,
                                             isSelfie: cameraManager.isFrontCameraActive,
                                             isFromCameraRoll: isCurrentImageFromCameraRoll)
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
                                   HStack(alignment: .bottom) {
                                       // Gallery Button
                                       Button(action: {
                                           showPhotoPicker = true
                                       }) {
                                           Image(systemName: "photo.on.rectangle")
                                               .font(.title2)
                                               .foregroundColor(.white)
                                               .padding()
                                               .background(Color.black.opacity(0.5))
                                               .clipShape(Circle())
                                       }
                                       .padding(.leading)

                                       Spacer() // Center the new VStack

                                       //<-----CHANGE START------>
                                       // VStack for Capture Button and Switch Camera Button
                                       VStack(spacing: 15) { // Add spacing between buttons
                                           // Camera Switch Button (smaller)
                                           Button(action: cameraManager.switchCamera) {
                                               Image(systemName: "arrow.triangle.2.circlepath.camera")
                                                   .font(.title3) // Smaller icon
                                                   .foregroundColor(.white)
                                                   .padding(10) // Smaller padding
                                                   .background(Color.black.opacity(0.5))
                                                   .clipShape(Circle())
                                           }

                                           // Capture Button
                                           Button(action: cameraManager.capturePhoto) {
                                                ZStack {
                                                    Circle().fill(.white).frame(width: 65, height: 65)
                                                    Circle().stroke(.white, lineWidth: 2).frame(width: 75, height: 75)
                                                }
                                                .shadow(radius: 5)
                                           }
                                       }
                                       //<-----CHANGE END-------->

                                       Spacer() // Right align list button

                                       // --- Image List Button with Badge ---
                                       NavigationLink(destination: ImageListView()) {
                                            ZStack(alignment: .topTrailing) { // Use ZStack for badge positioning
                                                // Base Button Content
                                                Image(systemName: "photo.stack")
                                                    .font(.title2)
                                                    .foregroundColor(.white)
                                                    .padding() // Padding for the icon itself
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())

                                                // Badge Overlay (only if count > 0)
                                                if imageDataManager.activelyProcessingCount > 0 {
                                                     Text("\(imageDataManager.activelyProcessingCount)")
                                                         .font(.caption2.bold())
                                                         .foregroundColor(.white)
                                                         .padding(5) // Padding inside the circle
                                                         .background(Color.red)
                                                         .clipShape(Circle())
                                                         // Offset the badge slightly
                                                         .offset(x: 5, y: -5)
                                                }
                                            }
                                        }
                                        .padding(.trailing)

                                   } // End HStack for bottom controls
                                   .padding(.bottom, 40) // Padding from bottom edge

                               } // End VStack for bottom controls layout

                               // --- Upload Success Popup Overlay ---
                               // Added overlay within the ZStack containing CameraLiveView
                               VStack {
                                    if showSuccessPopup {
                                        // Use the new view from the separate file
                                        UploadSuccessPopupView()
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
                            // <-----CHANGE START------>
                            // --- Top Left: Usages/Payments Icon ---
                            .overlay(alignment: .topLeading) {
                                // Changed NavigationLink to Button to present as a sheet
                                Button(action: {
                                    showPaymentsSheet = true // Set state to true to show the sheet
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(.blue)
                                        Text("\(userManager.userCredits ?? -1)") // Display -1 if nil, for debugging or placeholder
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.white).opacity(0.5))
                                    .cornerRadius(20) // Capsule shape
                                }
                                .padding([.top, .leading], 16)
                            }
                            // <-----CHANGE END-------->
                           // --- Top Right: Settings Button Overlay ---
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
              .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images, preferredItemEncoding: .current)
              .onChange(of: photoPickerItem) { oldValue, newValue in
                  if let item = newValue {
                      Task {
                          if let data = try? await item.loadTransferable(type: Data.self),
                             let uiImage = UIImage(data: data) {
                              await MainActor.run {
                                  self.isCurrentImageFromCameraRoll = true // ADDED: Set flag for camera roll image
                                  cameraManager.capturedImage = uiImage
                                  photoPickerItem = nil
                              }
                          }
                      }
                  }
              }
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
                       self.isCurrentImageFromCameraRoll = false // ADDED: Reset flag when image is cleared
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
              // --- Sheet for PaymentsView ---
              .sheet(isPresented: $showPaymentsSheet) { // <<< ADDED: Sheet modifier
                  PaymentsView()
                    // PaymentsView will inherit necessary EnvironmentObjects like storeManager and userManager
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
             Button("Continue", action: onRequestPermission)
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
