// MARK: MODIFIED FILE - Views/SettingsView.swift
// Updated to clear ImageDataManager cache on logout

import SwiftUI

struct UserInfoView: View {
     @EnvironmentObject var userManager: UserManager
     // MARK: <<< ADDED START >>>
     // Inject ImageDataManager to clear cache
     @EnvironmentObject var imageDataManager: ImageDataManager
     // MARK: <<< ADDED END >>>

     var body: some View {
          Form {
              Section("Account") {
                   Text("Username: \(userManager.userName ?? "N/A")")
                   Text("User ID: \(userManager.userIdentifier ?? "N/A")")
                   Button("Log Out", role: .destructive) {
                        // MARK: <<< MODIFIED START >>>
                        // Clear image cache BEFORE clearing user credentials
                        print("SettingsView: Logging out. Clearing image cache.")
                        imageDataManager.clearCache()
                        // Then clear user session
                        userManager.clearUser()
                        // MARK: <<< MODIFIED END >>>
                   }
              }
              // Add other settings sections...
          }
          .navigationTitle("User")
     }
}
// MARK: END MODIFIED FILE - Views/SettingsView.swift
