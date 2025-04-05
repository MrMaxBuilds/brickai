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
        VStack {
            Text("Settings for \(userManager.userName ?? "User")")
                .font(.title)
            Spacer()
        }
        .navigationTitle("Settings")
    }
}