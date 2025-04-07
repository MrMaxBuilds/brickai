// MARK: MODIFIED FILE - BrickAIApp.swift
//
//  BrickAIApp.swift
//  BrickAI
//
//  Created by Max U on 4/5/25.
//

import SwiftUI

@main
struct BrickAIApp: App {
    // MARK: <<< MODIFIED START >>>
    // Instantiate UserManager and ImageDataManager as StateObjects at the top level
    @StateObject private var userManager = UserManager.shared // Keep as singleton access if preferred
    @StateObject private var imageDataManager = ImageDataManager()
    // MARK: <<< MODIFIED END >>>

    var body: some Scene {
        WindowGroup {
            // MARK: <<< MODIFIED START >>>
            // Pass both managers into the environment
            LoginView()
              .environmentObject(userManager)
              .environmentObject(imageDataManager) // Inject ImageDataManager
            // MARK: <<< MODIFIED END >>>
        }
    }
}
// MARK: END MODIFIED FILE - BrickAIApp.swift