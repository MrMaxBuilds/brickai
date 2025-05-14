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
     @State private var showingDeleteConfirmation = false // Added for delete confirmation

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
                   }
                   // <-----CHANGE START------>
                   // Added Delete Account Button
                   Button("Delete Account", role: .destructive) {
                        showingDeleteConfirmation = true
                   }
                   // <-----CHANGE END-------->
              }
              // Add other settings sections...
          }
          .navigationTitle("User")
          // <-----CHANGE START------>
          // Added Alert for Delete Confirmation
          .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
              Button("Cancel", role: .cancel) { }
              Button("Yes, Delete", role: .destructive) {
                  print("UserInfoView: Delete confirmation received.")
                  // <-----CHANGE START------>
                  // Call UserManager to delete account
                  userManager.deleteCurrentUserAccount { result in
                      switch result {
                      case .success:
                          print("UserInfoView: Account deletion process successful. Performing local cleanup.")
                          // local data cleanup after successful account deletion
                          print("UserInfoView: Stopping image polling post-delete.")
                          imageDataManager.stopPolling()
                          print("UserInfoView: Clearing image cache post-delete.")
                          imageDataManager.clearCache()
                          // userManager.clearUser() is now called within deleteCurrentUserAccount
                          print("UserInfoView: User state should be cleared by UserManager.")
                      case .failure(let error):
                          // Handle error (e.g., show an alert to the user)
                          print("UserInfoView: Account deletion failed: \(error.localizedDescription)")
                          // Optionally, present an error alert to the user here
                      }
                  }
                  // <-----CHANGE END-------->
              }
          } message: {
              Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
          }
          // <-----CHANGE END-------->
     }
}
// MARK: END MODIFIED FILE - Views/UserInfoView.swift
