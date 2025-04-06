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
        // Determine initial login state based on whether userIdentifier was successfully loaded
        self.isLoggedIn = (self.userIdentifier != nil && !self.userIdentifier!.isEmpty)
        print("UserManager Initialized. UserIdentifier loaded: \(self.userIdentifier != nil), UserName loaded: \(self.userName != nil), Determined isLoggedIn: \(self.isLoggedIn)")
    }

    // Method to securely save user credentials after successful login
    func saveCredentials(userName: String?, userIdentifier: String, identityTokenData: Data) {
        do {
            // --- Save to Keychain ---
            // Save the stable user identifier
            try KeychainService.saveString(userIdentifier, forKey: kKeychainAccountUserIdentifier)
            
            // Save the user name (handle nil or empty)
            if let name = userName, !name.isEmpty {
                 try KeychainService.saveString(name, forKey: kKeychainAccountUserName)
            } else {
                 // If name is nil or empty, remove it from Keychain
                 try KeychainService.deleteData(forKey: kKeychainAccountUserName)
            }
            
            // Save the sensitive identity token data
            try KeychainService.saveData(identityTokenData, forKey: kKeychainAccountIdentityToken)

            // --- Update Internal State (on Main Thread for UI) ---
            // This ensures @Published properties trigger UI updates correctly.
            DispatchQueue.main.async {
                self.userIdentifier = userIdentifier // Update internal state
                self.userName = userName // Update internal state (might be nil)
                self.isLoggedIn = true // Set logged-in state
                print("UserManager: Credentials saved successfully. isLoggedIn set to true.")
            }
        } catch {
            // --- Handle Save Errors ---
            print("UserManager: Failed to save credentials to Keychain: \(error.localizedDescription)")
            // If saving fails, ensure inconsistent state isn't left behind. Clear everything.
             DispatchQueue.main.async {
                 self.clearUser() // Call clearUser to reset state and Keychain attempt
                 // Optionally: Propagate error to UI to inform user
             }
        }
    }

    // Method to retrieve the identity token from Keychain when needed for API calls
    func getIdentityToken() -> String? {
        do {
            let tokenData = try KeychainService.loadData(forKey: kKeychainAccountIdentityToken)
            // Convert Data to Base64 encoded String as expected by Bearer token format
            let tokenString = tokenData.base64EncodedString()
            
            // --- OPTIONAL PRODUCTION STEP: Validate Token Expiry ---
            // You would typically decode the JWT *here* (using a library like JWTDecode.swift)
            // and check the 'exp' claim against the current time *before* returning it.
            // If expired, you might return nil and potentially trigger a token refresh flow.
            // Example (pseudo-code, requires JWT decoding):
            // if let expiry = decode(tokenString).expiresAt, expiry < Date() {
            //     print("UserManager: Identity token retrieved but is expired.")
            //     // Optionally: Initiate token refresh here if using refresh tokens
            //     // Optionally: Clear expired token? Or let server handle 401?
            //     // try? KeychainService.deleteData(forKey: kKeychainAccountIdentityToken)
            //     return nil // Don't return expired token
            // }
            // --------------------------------------------------------
            
            print("UserManager: Retrieved identity token from Keychain successfully.")
            return tokenString
        } catch KeychainError.itemNotFound {
            // This is an expected case if the user isn't logged in or token was cleared
            print("UserManager: Identity token not found in Keychain.")
            return nil
        } catch {
            // Log other unexpected errors during loading
            print("UserManager: Failed to load identity token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    // Method to clear user credentials on logout
    func clearUser() {
        do {
            // --- Clear Keychain ---
            try KeychainService.deleteData(forKey: kKeychainAccountUserIdentifier)
            try KeychainService.deleteData(forKey: kKeychainAccountIdentityToken)
            try KeychainService.deleteData(forKey: kKeychainAccountUserName)
            
            // --- Update Internal State (on Main Thread for UI) ---
            DispatchQueue.main.async {
                self.userIdentifier = nil
                self.userName = nil
                self.isLoggedIn = false // Set logged-out state
                print("UserManager: User data cleared from Keychain and state updated. isLoggedIn set to false.")
            }
        } catch {
             print("UserManager: Failed to clear user data from Keychain: \(error.localizedDescription)")
             // Even if deletion fails (which is unlikely unless permissions change),
             // still update the internal state to reflect logged-out status.
             DispatchQueue.main.async {
                  self.userIdentifier = nil
                  self.userName = nil
                  self.isLoggedIn = false
             }
        }
    }
}
