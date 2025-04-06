//
//  SettingsView.swift
//  Epic Shots
//
//  Created by Max U on 3/25/25.
//


import SwiftUI

struct SettingsView: View {
     @EnvironmentObject var userManager: UserManager
     var body: some View {
          Form { // Example using Form for settings layout
              Section("Account") {
                   Text("Username: \(userManager.userName ?? "N/A")")
                   Text("User ID: \(userManager.userIdentifier ?? "N/A")")
                   Button("Log Out", role: .destructive) {
                        userManager.clearUser()
                   }
              }
              // Add other settings sections...
          }
          .navigationTitle("Settings")
     }
}
