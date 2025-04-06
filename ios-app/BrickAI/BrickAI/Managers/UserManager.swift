// File: BrickAI/Managers/UserManager.swift
// Full Untruncated File - Added updateSessionToken function

import Foundation
import Combine // Required for ObservableObject

class UserManager: ObservableObject {
    static let shared = UserManager() // Singleton pattern

    // Published properties trigger UI updates.
    @Published private(set) var userName: String?
    @Published private(set) var userIdentifier: String?
    @Published private(set) var isLoggedIn: Bool = false

    private init() {
        self.userIdentifier = KeychainService.loadString(forKey: kKeychainAccountUserIdentifier)
        self.userName = KeychainService.loadString(forKey: kKeychainAccountUserName)
        let sessionToken = KeychainService.loadString(forKey: kKeychainAccountSessionToken)
        self.isLoggedIn = (self.userIdentifier != nil && !self.userIdentifier!.isEmpty && sessionToken != nil && !sessionToken!.isEmpty)
        print("UserManager Initialized. UserIdentifier loaded: \(self.userIdentifier != nil), UserName loaded: \(self.userName != nil), SessionToken loaded: \(sessionToken != nil). Determined isLoggedIn: \(self.isLoggedIn)")
    }

    // Save initial credentials and session token
    func saveCredentials(userName: String?, userIdentifier: String, sessionToken: String) {
        do {
            try KeychainService.saveString(userIdentifier, forKey: kKeychainAccountUserIdentifier)
            if let name = userName, !name.isEmpty {
                try KeychainService.saveString(name, forKey: kKeychainAccountUserName)
            } else {
                try? KeychainService.deleteData(forKey: kKeychainAccountUserName)
            }
            try KeychainService.saveString(sessionToken, forKey: kKeychainAccountSessionToken)

            DispatchQueue.main.async {
                self.userIdentifier = userIdentifier
                self.userName = userName
                self.isLoggedIn = true
                print("UserManager: Credentials and session token saved successfully. isLoggedIn set to true.")
            }
        } catch {
            print("UserManager: Failed to save credentials/session token to Keychain: \(error.localizedDescription)")
            DispatchQueue.main.async { self.clearUser() }
        }
    }

    // Retrieve the current backend session token
    func getSessionToken() -> String? {
        do {
            guard let tokenString = KeychainService.loadString(forKey: kKeychainAccountSessionToken) else {
                throw KeychainError.itemNotFound
            }
            // print("UserManager: Retrieved backend session token from Keychain successfully.") // Less verbose
            return tokenString
        } catch KeychainError.itemNotFound {
            print("UserManager: Backend session token not found in Keychain.")
            return nil
        } catch {
            print("UserManager: Failed to load backend session token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    // Update only the session token after a refresh
    func updateSessionToken(newToken: String) {
        do {
            try KeychainService.saveString(newToken, forKey: kKeychainAccountSessionToken)
            print("UserManager: Session token updated successfully in Keychain.")
            // Ensure isLoggedIn remains true if it was already true
            // No need to change userIdentifier or userName here.
            if !self.isLoggedIn {
                // This case shouldn't really happen during a refresh, but safeguard
                DispatchQueue.main.async {
                    // Re-check based on existence of user ID and new token
                    self.userIdentifier = KeychainService.loadString(forKey: kKeychainAccountUserIdentifier)
                    self.isLoggedIn = (self.userIdentifier != nil && !self.userIdentifier!.isEmpty)
                    print("UserManager: Warning - isLoggedIn was false during token update. Resetting based on user ID presence.")
                }
            }
        } catch {
            print("UserManager: Failed to update session token in Keychain: \(error.localizedDescription)")
            // Consider if we need to logout user if token update fails critically
            // DispatchQueue.main.async { self.clearUser() }
        }
    }

    // Clear user data and session token
    func clearUser() {
        // Use try? for non-critical deletions
        try? KeychainService.deleteData(forKey: kKeychainAccountUserIdentifier)
        try? KeychainService.deleteData(forKey: kKeychainAccountSessionToken)
        try? KeychainService.deleteData(forKey: kKeychainAccountUserName)

        DispatchQueue.main.async {
            self.userIdentifier = nil
            self.userName = nil
            self.isLoggedIn = false
            print("UserManager: User data and session token cleared from Keychain and state updated. isLoggedIn set to false.")
        }
        // Note: Don't need the extra catch block if using try? extensively above
    }
}
