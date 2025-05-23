// MARK: MODIFIED FILE - Managers/UserManager.swift
// File: BrickAI/Managers/UserManager.swift
// Removed direct dependency on ImageDataManager

import Foundation
import Combine

class UserManager: ObservableObject {
    static let shared = UserManager() // Keep as singleton for easy access if needed elsewhere, but LoginView uses EnvironmentObject

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

            // MARK: <<< REMOVED START >>>
            // let wasAlreadyLoggedIn = self.isLoggedIn // No longer needed here
            // MARK: <<< REMOVED END >>>

            DispatchQueue.main.async {
                self.userIdentifier = userIdentifier
                self.userName = userName
                self.isLoggedIn = true
                print("UserManager: Credentials and session token saved successfully. isLoggedIn set to true.")

                // MARK: <<< REMOVED START >>>
                // Remove trigger from saveCredentials
                /*
                 if !wasAlreadyLoggedIn {
                      print("UserManager: Login successful. Triggering image data preparation.")
                      self.imageDataManager.prepareImageData()
                 }
                */
                 // MARK: <<< REMOVED END >>>
            }
        } catch {
            print("UserManager: Failed to save credentials/session token to Keychain: \(error.localizedDescription)")
            DispatchQueue.main.async { self.clearUser() }
        }
    }

    // Retrieve the current backend session token (Unchanged)
    func getSessionToken() -> String? {
        // ... (no changes needed here) ...
        do {
            guard let tokenString = KeychainService.loadString(forKey: kKeychainAccountSessionToken) else {
                throw KeychainError.itemNotFound
            }
            return tokenString
        } catch KeychainError.itemNotFound {
            print("UserManager: Backend session token not found in Keychain.")
            return nil
        } catch {
            print("UserManager: Failed to load backend session token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    // Update only the session token after a refresh (Unchanged)
    func updateSessionToken(newToken: String) {
        // ... (no changes needed here) ...
        do {
            try KeychainService.saveString(newToken, forKey: kKeychainAccountSessionToken)
            print("UserManager: Session token updated successfully in Keychain.")
            if !self.isLoggedIn {
                DispatchQueue.main.async {
                    self.userIdentifier = KeychainService.loadString(forKey: kKeychainAccountUserIdentifier)
                    self.isLoggedIn = (self.userIdentifier != nil && !self.userIdentifier!.isEmpty)
                    print("UserManager: Warning - isLoggedIn was false during token update. Resetting based on user ID presence.")
                     // MARK: <<< REMOVED START >>>
                     // Remove trigger from updateSessionToken
                     /*
                     if self.isLoggedIn {
                          print("UserManager: Became logged in during token update. Triggering image data prep.")
                           self.imageDataManager.prepareImageData()
                     }
                    */
                    // MARK: <<< REMOVED END >>>
                }
            }
        } catch {
            print("UserManager: Failed to update session token in Keychain: \(error.localizedDescription)")
        }
    }

    // Clear user data and session token
    func clearUser() {
        // Use try? for non-critical deletions
        try? KeychainService.deleteData(forKey: kKeychainAccountUserIdentifier)
        try? KeychainService.deleteData(forKey: kKeychainAccountSessionToken)
        try? KeychainService.deleteData(forKey: kKeychainAccountUserName)

        DispatchQueue.main.async {
            // MARK: <<< REMOVED START >>>
            // let wasLoggedIn = self.isLoggedIn // No longer needed here
            // MARK: <<< REMOVED END >>>
            self.userIdentifier = nil
            self.userName = nil
            self.isLoggedIn = false
            print("UserManager: User data and session token cleared from Keychain and state updated. isLoggedIn set to false.")
        }
    }

    // Function to delete the current user's account
    func deleteCurrentUserAccount(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        print("UserManager: Attempting to delete current user account.")
        NetworkManager.deleteAccount { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("UserManager: Account deletion successful via NetworkManager. Clearing local user data.")
                    self.clearUser() // Clear local user credentials and state
                    completion(.success(()))
                case .failure(let error):
                    print("UserManager: Account deletion failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
}
// MARK: END MODIFIED FILE - Managers/UserManager.swift