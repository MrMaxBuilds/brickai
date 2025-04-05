//
//  BrickAIApp.swift
//  BrickAI
//
//  Created by Max U on 4/5/25.
//

import SwiftUI

@main
struct BrickAIApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
              .environmentObject(UserManager.shared)
        }
    }
}
