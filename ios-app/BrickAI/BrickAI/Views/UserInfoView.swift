// MARK: MODIFIED FILE - Views/UserInfoView.swift
// Updated to clear ImageDataManager cache on logout
// <-----CHANGE START------>
// Added call to stop ImageDataManager polling on logout
// <-----CHANGE END-------->


import SwiftUI

struct UserInfoView: View {
     @EnvironmentObject var userManager: UserManager
     // Inject ImageDataManager to clear cache and stop polling
     @EnvironmentObject var imageDataManager: ImageDataManager

     var body: some View {
          Form {
              Section("Account") {
                   Text("Username: \(userManager.userName ?? "N/A")")
                   Text("User ID: \(userManager.userIdentifier ?? "N/A")")
                   Button("Log Out", role: .destructive) {
                        // <-----CHANGE START------>
                        // 1. Stop polling BEFORE clearing cache/user
                        print("UserInfoView: Logging out. Stopping image polling.")
                        imageDataManager.stopPolling()
                        // 2. Clear image cache
                        print("UserInfoView: Clearing image cache.")
                        imageDataManager.clearCache()
                        // 3. Then clear user session
                        print("UserInfoView: Clearing user credentials.")
                        userManager.clearUser()
                        // <-----CHANGE END-------->
                   }
              }
              // Add other settings sections...
          }
          .navigationTitle("User")
     }
}
// MARK: END MODIFIED FILE - Views/UserInfoView.swift