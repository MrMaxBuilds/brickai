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
    // Instantiate UserManager and ImageDataManager as StateObjects at the top level
    @StateObject private var userManager = UserManager.shared
    @StateObject private var imageDataManager = ImageDataManager()
    // <-----CHANGE START------>
    // Instantiate StoreManager as a StateObject
    @StateObject private var storeManager = StoreManager()
    // <-----CHANGE END-------->

    var body: some Scene {
        WindowGroup {
            // Pass all managers into the environment
            LoginView()
              .environmentObject(userManager)
              .environmentObject(imageDataManager)
              // <-----CHANGE START------>
              .environmentObject(storeManager) // Inject StoreManager
              // <-----CHANGE END-------->
        }
    }
}
// MARK: END MODIFIED FILE - BrickAIApp.swift
