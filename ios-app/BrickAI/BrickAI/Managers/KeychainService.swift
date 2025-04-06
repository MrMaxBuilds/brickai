// File: BrickAI/Managers/KeychainService.swift
// Full Untruncated File

import Foundation
import Security

// Service identifier for Keychain items specific to this app
// Using the bundle ID is a common practice to avoid collisions
let kKeychainService = Bundle.main.bundleIdentifier ?? "com.default.keychainservice"

// Account keys used to identify specific data items
let kKeychainAccountUserIdentifier = "appleUserIdentifier"
// DEPRECATED - let kKeychainAccountIdentityToken = "appleIdentityToken" // No longer storing Apple identity token directly
let kKeychainAccountSessionToken = "backendSessionToken" // Key for storing our backend session token
let kKeychainAccountUserName = "userName" // Can also store username if desired

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem // Although we try to avoid this with delete-then-add or update
    case unexpectedData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found."
        case .duplicateItem:
            return "Keychain item already exists."
        case .unexpectedData:
            return "Unexpected data format retrieved from Keychain."
        case .unhandledError(let status):
            // Provide a more descriptive error if possible using SecCopyErrorMessageString
            // However, that function is not available on all platforms/versions directly in Swift easily.
            return "Keychain operation failed with OSStatus: \(status)"
        }
    }
}

struct KeychainService {

    // Generic function to save data to Keychain
    static func saveData(_ data: Data, forKey accountKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            // Set accessibility - item accessible only when device is unlocked
            // This is a reasonable default for user credentials/tokens.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item first to ensure we replace it cleanly.
        // This simplifies the logic compared to checking existence then deciding Add vs Update.
        // Ignore itemNotFound error during delete, as it means we're just adding fresh.
        do {
            try deleteData(forKey: accountKey)
        } catch KeychainError.itemNotFound {
            // This is expected if the item doesn't exist yet. Continue to add.
        } catch {
             // Rethrow other unexpected delete errors
             throw error
        }


        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            // If deletion failed silently and we hit duplicate, something is wrong.
            print("Keychain: Error saving data for key '\(accountKey)'. Status: \(status)")
            throw KeychainError.unhandledError(status: status)
        }
         print("Keychain: Successfully saved data for key '\(accountKey)'")
    }

    // Generic function to load data from Keychain
    static func loadData(forKey accountKey: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: accountKey,
            kSecMatchLimit as String: kSecMatchLimitOne,  // We expect only one item per key
            kSecReturnData as String: kCFBooleanTrue!     // Request data back
        ]

        var item: CFTypeRef? // Use CFTypeRef for the result
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        // Check for specific errors
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        // Check for generic success
        guard status == errSecSuccess else {
            print("Keychain: Error loading data for key '\(accountKey)'. Status: \(status)")
            throw KeychainError.unhandledError(status: status)
        }
        // Check if the retrieved item is actually Data
        guard let data = item as? Data else {
            // This indicates an unexpected item type was stored or retrieved
            throw KeychainError.unexpectedData
        }

        print("Keychain: Successfully loaded data for key '\(accountKey)'")
        return data
    }

    // Generic function to update existing data in Keychain (Less used with delete-then-add strategy)
    // Kept for completeness or alternative implementations.
    static func updateData(_ data: Data, forKey accountKey: String) throws {
         let query: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: kKeychainService,
             kSecAttrAccount as String: accountKey
             // Do not specify kSecMatchLimitOne for update
         ]

         // Attributes to update
         let attributes: [String: Any] = [
             kSecValueData as String: data
             // Could potentially update kSecAttrAccessible here too if needed
         ]

         let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
         // Check specific errors
         guard status != errSecItemNotFound else {
             // Cannot update an item that doesn't exist
             throw KeychainError.itemNotFound
         }
         // Check generic success
         guard status == errSecSuccess else {
            print("Keychain: Error updating data for key '\(accountKey)'. Status: \(status)")
             throw KeychainError.unhandledError(status: status)
         }
          print("Keychain: Successfully updated data for key '\(accountKey)'")
     }


    // Generic function to delete data from Keychain
    static func deleteData(forKey accountKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: kKeychainService,
            kSecAttrAccount as String: accountKey
            // No kSecMatchLimit needed for delete (deletes all matching if multiple existed, though our keys should be unique)
        ]

        let status = SecItemDelete(query as CFDictionary)
        // Treat itemNotFound as success (idempotent delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("Keychain: Error deleting data for key '\(accountKey)'. Status: \(status)")
            throw KeychainError.unhandledError(status: status)
        }
         if status == errSecSuccess {
              print("Keychain: Successfully deleted data for key '\(accountKey)'")
         } else {
              // This log might be redundant if throwing itemNotFound, but useful for clarity
              print("Keychain: No data found to delete for key '\(accountKey)'")
         }
    }

    // --- Convenience methods for String ---

    static func saveString(_ string: String, forKey accountKey: String) throws {
        // Convert String to Data using UTF-8 encoding
        guard let data = string.data(using: .utf8) else {
            print("Error converting string to data for key: \(accountKey)")
            // Throw an appropriate error if conversion fails
            throw KeychainError.unexpectedData // Or a more specific encoding error
        }
        // Call the primary saveData function
        try saveData(data, forKey: accountKey)
    }

    static func loadString(forKey accountKey: String) -> String? {
        do {
            // Call the primary loadData function
            let data = try loadData(forKey: accountKey)
            // Convert retrieved Data back to String using UTF-8
            return String(data: data, encoding: .utf8)
        } catch KeychainError.itemNotFound {
            // Item not found is often an expected case during loading, return nil
            print("Keychain: No string found for key '\(accountKey)'")
            return nil
        } catch {
            // Log other unexpected errors during loading
            print("Keychain: Failed to load string for key '\(accountKey)': \(error.localizedDescription)")
            return nil // Return nil on other errors
        }
    }
}