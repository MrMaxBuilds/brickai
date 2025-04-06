// File: BrickAI/Managers/UserManager.swift
// Full Untruncated File

import Foundation
import Combine // Required for ObservableObject

class UserManager: ObservableObject {
    static let shared = UserManager() // Singleton pattern

    // Published properties trigger UI updates.
    // Use private(set) to ensure they are only mutated within this class (via methods).
    @Published private(set) var userName: String?
    @Published private(set) var userIdentifier: String?
    // Explicit state reflecting whether necessary user identifiers are loaded/present.
    @Published private(set) var isLoggedIn: Bool = false

    // Initialize by attempting to load credentials from Keychain
    private init() {
        self.userIdentifier = KeychainService.loadString(forKey: kKeychainAccountUserIdentifier)
        self.userName = KeychainService.loadString(forKey: kKeychainAccountUserName)
        // Determine initial login state based on whether userIdentifier AND session token exist
        let sessionToken = KeychainService.loadString(forKey: kKeychainAccountSessionToken)
        self.isLoggedIn = (self.userIdentifier != nil && !self.userIdentifier!.isEmpty && sessionToken != nil && !sessionToken!.isEmpty)
        print("UserManager Initialized. UserIdentifier loaded: \(self.userIdentifier != nil), UserName loaded: \(self.userName != nil), SessionToken loaded: \(sessionToken != nil). Determined isLoggedIn: \(self.isLoggedIn)")
    }

    // Method to securely save user credentials AND the backend session token
    // Changed signature: now accepts sessionToken (String) instead of identityTokenData (Data)
    func saveCredentials(userName: String?, userIdentifier: String, sessionToken: String) {
        do {
            // --- Save to Keychain ---
            // Save the stable user identifier
            try KeychainService.saveString(userIdentifier, forKey: kKeychainAccountUserIdentifier)

            // Save the user name (handle nil or empty)
            if let name = userName, !name.isEmpty {
                 try KeychainService.saveString(name, forKey: kKeychainAccountUserName)
            } else {
                 // If name is nil or empty, remove it from Keychain
                 // Use try? as we don't want failure here to stop the whole process
                 try? KeychainService.deleteData(forKey: kKeychainAccountUserName)
            }

            // Save the backend session token (String)
            try KeychainService.saveString(sessionToken, forKey: kKeychainAccountSessionToken)

            // --- Update Internal State (on Main Thread for UI) ---
            // This ensures @Published properties trigger UI updates correctly.
            DispatchQueue.main.async {
                self.userIdentifier = userIdentifier // Update internal state
                self.userName = userName // Update internal state (might be nil)
                self.isLoggedIn = true // Set logged-in state
                print("UserManager: Credentials and session token saved successfully. isLoggedIn set to true.")
            }
        } catch {
            // --- Handle Save Errors ---
            print("UserManager: Failed to save credentials/session token to Keychain: \(error.localizedDescription)")
            // If saving fails, ensure inconsistent state isn't left behind. Clear everything.
             DispatchQueue.main.async {
                 self.clearUser() // Call clearUser to reset state and Keychain attempt
                 // Optionally: Propagate error to UI to inform user
             }
        }
    }

    // Method to retrieve the backend session token from Keychain when needed for API calls
    // Renamed from getIdentityToken to getSessionToken
    func getSessionToken() -> String? {
        do {
            // Load the string directly using the convenience method
            guard let tokenString = KeychainService.loadString(forKey: kKeychainAccountSessionToken) else {
                 throw KeychainError.itemNotFound // Or handle nil return if loadString doesn't throw on not found
            }

            // --- REMOVED: Expiry Check ---
            // The backend is responsible for validating its own session tokens.
            // Client-side expiry checks for backend tokens are less common unless
            // the token itself contains an easily readable 'exp' claim and you want
            // proactive checks, but it adds complexity. Let the backend handle 401s.
            // ----------------------------

            print("UserManager: Retrieved backend session token from Keychain successfully.")
            return tokenString
        } catch KeychainError.itemNotFound {
            // This is an expected case if the user isn't logged in or token was cleared
            print("UserManager: Backend session token not found in Keychain.")
            return nil
        } catch {
            // Log other unexpected errors during loading
            print("UserManager: Failed to load backend session token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    // Method to clear user credentials and session token on logout
    func clearUser() {
        do {
            // --- Clear Keychain ---
            // Use try? to attempt deletion even if one fails (e.g., already deleted)
            try? KeychainService.deleteData(forKey: kKeychainAccountUserIdentifier)
            try? KeychainService.deleteData(forKey: kKeychainAccountSessionToken) // Delete session token
            try? KeychainService.deleteData(forKey: kKeychainAccountUserName)
            // try? KeychainService.deleteData(forKey: kKeychainAccountIdentityToken) // Ensure old key is gone if needed

            // --- Update Internal State (on Main Thread for UI) ---
            DispatchQueue.main.async {
                self.userIdentifier = nil
                self.userName = nil
                self.isLoggedIn = false // Set logged-out state
                print("UserManager: User data and session token cleared from Keychain and state updated. isLoggedIn set to false.")
            }
        } catch {
             // This catch block might be less likely to be hit with try? above,
             // but keep it as a fallback.
             print("UserManager: Error occurred during Keychain data clearing (though individual deletions might ignore errors): \(error.localizedDescription)")
             // Even if deletion fails, still update the internal state to reflect logged-out status.
             DispatchQueue.main.async {
                  self.userIdentifier = nil
                  self.userName = nil
                  self.isLoggedIn = false
             }
        }
    }
}
