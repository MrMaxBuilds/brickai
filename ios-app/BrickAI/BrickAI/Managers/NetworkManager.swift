// MARK: MODIFIED FILE - Managers/NetworkManager.swift
// File: BrickAI/Managers/NetworkManager.swift
// Full Untruncated File - Added Equatable conformance to NetworkError.

import Foundation
import UIKit

// MARK: <<< ADDED START >>>
// UserInfo struct to match backend response
struct UserInfo: Decodable {
    let appleUserId: String
    let credits: Int
}

// MARK: <<< ADDED START >>>
// Specific response structures for API endpoints
struct AddCreditsResponse: Decodable {
    let message: String
    let userInfo: UserInfo
}

struct UploadResponse: Decodable {
    let message: String
    let url: String?
    let userInfo: UserInfo
}

struct ImagesResponse: Decodable {
    let images: [ImageData] // Assumes ImageData is Decodable
    let userInfo: UserInfo
}
// MARK: <<< ADDED END >>>

// MARK: <<< MODIFIED START >>>
// NetworkError Enum - Added Equatable conformance
enum NetworkError: Error, LocalizedError, Equatable {
// MARK: <<< MODIFIED END >>>
    case invalidURL(String)
    case dataConversionFailed
    case authenticationTokenMissing
    case networkRequestFailed(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized // Specific 401 before refresh attempt
    case unexpectedResponse
    case authCodeExchangeFailed(String)
    case tokenRefreshFailed(String)
    case sessionExpired // Terminal refresh failure

    var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString): return "The configured API endpoint URL is invalid: \(urlString)"
        case .dataConversionFailed: return "Failed to convert image to data format."
        case .authenticationTokenMissing: return "User authentication token is missing. Please log in."
        case .networkRequestFailed(let underlyingError): return "Network request failed: \(underlyingError.localizedDescription)"
        case .serverError(let statusCode, let message):
             var desc = "Server returned an error (Status Code: \(statusCode))."
             if let msg = message, !msg.isEmpty { desc += " Message: \(msg)" }
             return desc
        case .unauthorized: return "Unauthorized: Session may require refresh."
        case .unexpectedResponse: return "Received an unexpected response format from the server."
        case .authCodeExchangeFailed(let message): return "Failed to exchange authorization code with backend: \(message)"
        case .tokenRefreshFailed(let message): return "Failed to refresh session token: \(message)"
        case .sessionExpired: return "Your session has expired. Please log in again."
        }
    }

    // MARK: <<< ADDED START >>>
    // Implementation of Equatable conformance
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let lhsString), .invalidURL(let rhsString)):
            return lhsString == rhsString
        case (.dataConversionFailed, .dataConversionFailed):
            return true
        case (.authenticationTokenMissing, .authenticationTokenMissing):
            return true
        case (.networkRequestFailed(let lhsError), .networkRequestFailed(let rhsError)):
            // Comparing actual Error objects is difficult.
            // Compare based on localizedDescription for pragmatic equality check.
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.unauthorized, .unauthorized):
            return true
        case (.unexpectedResponse, .unexpectedResponse):
            return true
        case (.authCodeExchangeFailed(let lhsMessage), .authCodeExchangeFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.tokenRefreshFailed(let lhsMessage), .tokenRefreshFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.sessionExpired, .sessionExpired):
            return true
        // If none of the cases match, they are not equal
        default:
            return false
        }
    }
    // MARK: <<< ADDED END >>>
}

// Actor to manage the refresh token state and prevent race conditions
actor TokenRefresher {
    private var isRefreshing = false
    // Stores continuations waiting for the refresh to complete
    private var waitingContinuations: [CheckedContinuation<String, Error>] = []

    // Attempts to refresh the token, ensuring only one refresh happens at a time.
    func refreshTokenIfNeeded() async throws -> String {
        if !isRefreshing {
            isRefreshing = true
            // Perform the actual refresh network call
            do {
                // IMPORTANT: Call the static function on NetworkManager, not directly accessing self
                let newToken = try await NetworkManager.performTokenRefresh()

                // Notify all waiting tasks with the new token - this runs on the actor
                waitingContinuations.forEach { $0.resume(returning: newToken) }
                waitingContinuations.removeAll()
                isRefreshing = false
                print("TokenRefresher: Refresh successful, notified \(waitingContinuations.count) waiters.")
                return newToken
            } catch {
                // Notify all waiting tasks about the failure - this runs on the actor
                print("TokenRefresher: Refresh failed, notifying \(waitingContinuations.count) waiters.")
                waitingContinuations.forEach { $0.resume(throwing: error) }
                waitingContinuations.removeAll()
                isRefreshing = false
                throw error // Re-throw the error
            }
        } else {
            // If already refreshing, wait for the result
            print("TokenRefresher: Refresh already in progress, waiting...")
            return try await withCheckedThrowingContinuation { continuation in
                 // Accessing actor state directly inside the actor's async function.
                 // The continuation itself is Sendable.
                 self.waitingContinuations.append(continuation)
            }
        }
    }
} // End Actor


class NetworkManager {

    private static let tokenRefresher = TokenRefresher() // Instance of the actor

    private static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Use a custom formatter that handles fractional seconds and timezone
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        return decoder
    }()
    
    private static var baseApiEndpointURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String else { return nil }
        let correctedUrlString = urlString.hasSuffix("/") ? urlString : urlString + "/"
        guard let url = URL(string: correctedUrlString) else { return nil }
        return url
    }
    
    private static func endpointURL(path: String) -> URL? {
        let correctedPath = path.starts(with: "/") ? String(path.dropFirst()) : path
        return baseApiEndpointURL?.appendingPathComponent(correctedPath)
    }

    // Centralized Request Execution Function
    private static func performRequest(
        originalRequest: URLRequest,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) {
        let mainThreadCompletion = { result in DispatchQueue.main.async { completion(result) } }

        guard let token = UserManager.shared.getSessionToken() else {
            mainThreadCompletion(.failure(.authenticationTokenMissing))
            return
        }
        var request = originalRequest
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // MARK: <<< MODIFIED START >>>
            // Always try to extract user credits from data, regardless of error or status code, if data exists
            if let data = data {
                self.tryExtractAndUpdateUserCredits(from: data)
            }
            // MARK: <<< MODIFIED END >>>

            if let error = error {
                mainThreadCompletion(.failure(.networkRequestFailed(error)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                mainThreadCompletion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                return
            }

            // Check for Unauthorized (401)
            if httpResponse.statusCode == 401 {
                print("NetworkManager: Received 401 Unauthorized for \(request.url?.absoluteString ?? "URL"). Attempting token refresh...")
                Task { // Use Task to call async actor function
                    do {
                        let newToken = try await tokenRefresher.refreshTokenIfNeeded()
                        print("NetworkManager: Token refresh successful via actor. Retrying original request...")

                        var retryRequest = originalRequest
                        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

                        let retryTask = URLSession.shared.dataTask(with: retryRequest) { retryData, retryResponse, retryError in
                            // MARK: <<< MODIFIED START >>>
                            // Always try to extract user credits from retryData if it exists
                            if let retryData = retryData {
                                self.tryExtractAndUpdateUserCredits(from: retryData)
                            }
                            // MARK: <<< MODIFIED END >>>

                            if let retryError = retryError {
                                mainThreadCompletion(.failure(.networkRequestFailed(retryError)))
                                return
                            }
                            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                                mainThreadCompletion(.failure(.serverError(statusCode: 0, message: "Invalid retry response type")))
                                return
                            }

                            if retryHttpResponse.statusCode == 401 { // If retry STILL fails with 401
                                print("NetworkManager: Retry request failed with 401. Session expired.")
                                UserManager.shared.clearUser()
                                mainThreadCompletion(.failure(.sessionExpired))
                                return
                            }
                            guard (200...299).contains(retryHttpResponse.statusCode) else {
                                let errorMessage = parseError(from: retryData, statusCode: retryHttpResponse.statusCode)
                                mainThreadCompletion(.failure(.serverError(statusCode: retryHttpResponse.statusCode, message: errorMessage)))
                                return
                            }
                            mainThreadCompletion(.success(retryData ?? Data()))
                        }
                        retryTask.resume()

                    } catch let refreshError as NetworkError {
                        print("NetworkManager: Token refresh failed: \(refreshError.localizedDescription)")
                        if case .sessionExpired = refreshError { UserManager.shared.clearUser() }
                        mainThreadCompletion(.failure(refreshError))
                    } catch {
                        print("NetworkManager: Unexpected error during token refresh: \(error.localizedDescription)")
                        mainThreadCompletion(.failure(.tokenRefreshFailed("Unexpected error during refresh.")))
                    }
                } // End Task
            } else { // Not a 401 error
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = parseError(from: data, statusCode: httpResponse.statusCode)
                    mainThreadCompletion(.failure(.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                    return
                }
                mainThreadCompletion(.success(data ?? Data()))
            }
        }
        task.resume()
    }

    // Internal function to perform the actual token refresh API call
    static func performTokenRefresh() async throws -> String {
        print("NetworkManager: Executing performTokenRefresh...")
        guard let refreshURL = endpointURL(path: "api/auth/refresh") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "NF") + "/api/auth/refresh"
            throw NetworkError.invalidURL(urlString)
        }
        guard let currentToken = UserManager.shared.getSessionToken() else { throw NetworkError.authenticationTokenMissing }

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetworkError.networkRequestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError(statusCode: 0, message: "Invalid response type")
        }

        if httpResponse.statusCode == 401 {
            throw NetworkError.sessionExpired // Treat 401 from refresh endpoint as session expired
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = parseError(from: data, statusCode: httpResponse.statusCode)
            throw NetworkError.tokenRefreshFailed(errorMessage)
        }

        // Parse success response
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newToken = jsonResponse["sessionToken"] as? String {
                UserManager.shared.updateSessionToken(newToken: newToken) // Update Keychain
                print("NetworkManager: Successfully received and saved new session token.")
                return newToken
            } else {
                throw NetworkError.unexpectedResponse
            }
        } catch {
            throw NetworkError.unexpectedResponse
        }
    }

    // Helper to parse error messages
    private static func parseError(from data: Data?, statusCode: Int) -> String {
        guard let data = data else { return "No error details provided." }
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                return errorMsg
            }
        } catch {
            // Ignore
        }
        return String(data: data, encoding: .utf8) ?? "Could not decode error message."
    }

    // Public API Functions
    static func uploadImage(_ image: UIImage, completion: @escaping (Result<String, NetworkError>) -> Void) {
        guard let endpoint = endpointURL(path: "api/upload") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "NF") + "/api/upload"
            DispatchQueue.main.async { completion(.failure(.invalidURL(urlString))) }
            return
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async { completion(.failure(.dataConversionFailed)) }
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        performRequest(originalRequest: request) { result in
            switch result {
            case .success(let data):
                do {
                    let uploadResponse = try self.jsonDecoder.decode(UploadResponse.self, from: data)
                    if let urlString = uploadResponse.url {
                        completion(.success(urlString))
                    } else {
                        print("NetworkManager: Upload successful but no URL in response.")
                        completion(.failure(.unexpectedResponse))
                    }
                } catch {
                    print("NetworkManager: Failed to decode UploadResponse: \(error.localizedDescription). Data: \(String(data: data, encoding: .utf8) ?? "non-utf8 data")")
                    completion(.failure(.unexpectedResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // exchangeAuthCode remains separate
    static func exchangeAuthCode(authorizationCode: String, completion: @escaping (Result<String, NetworkError>) -> Void) {
        guard let authCallbackURL = endpointURL(path: "api/auth/apple/callback") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "NF") + "/api/auth/apple/callback"
            DispatchQueue.main.async { completion(.failure(.invalidURL(urlString))) }
            return
        }
        
        let requestBody: [String: String] = ["authorizationCode": authorizationCode]
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            DispatchQueue.main.async { completion(.failure(.authCodeExchangeFailed("Failed to encode request."))) }
            return
        }
        
        var request = URLRequest(url: authCallbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkRequestFailed(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                    return
                }
                
                guard let responseData = data else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Missing response data.")))
                    return
                }
                
                var serverMessage: String? = nil
                var sessionToken: String? = nil
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        serverMessage = jsonResponse["error"] as? String ?? jsonResponse["message"] as? String
                        sessionToken = jsonResponse["sessionToken"] as? String
                    } else {
                        serverMessage = String(data: responseData, encoding: .utf8)
                    }
                } catch {
                    serverMessage = String(data: responseData, encoding: .utf8)
                }
                
                if (200...299).contains(httpResponse.statusCode), let token = sessionToken {
                    completion(.success(token))
                } else {
                    let errorMessage = serverMessage ?? "Auth code exchange failed status \(httpResponse.statusCode)."
                    completion(.failure(.authCodeExchangeFailed(errorMessage)))
                }
            }
        }
        task.resume()
    }

    static func fetchImages(completion: @escaping (Result<[ImageData], NetworkError>) -> Void) {
        guard let endpoint = endpointURL(path: "api/images") else {
            DispatchQueue.main.async { completion(.failure(.invalidURL("images"))) }
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        print("NetworkManager: Fetching images...")
        
        performRequest(originalRequest: request) { result in
            switch result {
            case .success(let data):
                do {
                    let imagesResponse = try self.jsonDecoder.decode(ImagesResponse.self, from: data)
                    print("NetworkManager: Successfully fetched and decoded \(imagesResponse.images.count) images.")
                    completion(.success(imagesResponse.images))
                } catch {
                    print("NetworkManager: Failed to decode ImagesResponse: \(error.localizedDescription). Data: \(String(data: data, encoding: .utf8) ?? "non-utf8 data")")
                    completion(.failure(.unexpectedResponse))
                }
            case .failure(let error):
                print("NetworkManager: Failed to fetch images: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // Added function to call the delete account API endpoint
    static func deleteAccount(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let endpoint = endpointURL(path: "api/account/delete") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "NF") + "/api/account/delete"
            DispatchQueue.main.async { completion(.failure(.invalidURL(urlString))) }
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        print("NetworkManager: Requesting account deletion...")

        performRequest(originalRequest: request) { result in
            switch result {
            case .success: // If performRequest succeeds, it means a 2xx response was received.
                // The backend returns a JSON message, but for the client, a 200/204 means success.
                print("NetworkManager: Account deletion request successful.")
                completion(.success(()))
            case .failure(let error):
                print("NetworkManager: Account deletion request failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    static func addCreditsForPurchase(productId: String, completion: @escaping (Result<Int, NetworkError>) -> Void) {
        guard let endpoint = endpointURL(path: "api/credits/add") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "NF") + "/api/credits/add"
            DispatchQueue.main.async { completion(.failure(.invalidURL(urlString))) }
            return
        }

        let requestBody: [String: String] = ["productId": productId]
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            DispatchQueue.main.async { completion(.failure(.dataConversionFailed)) } // Or a more specific error
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("NetworkManager: Attempting to add credits for product ID: \(productId)")

        performRequest(originalRequest: request) { result in
            switch result {
            case .success(let data):
                do {
                    let addCreditsResponse = try self.jsonDecoder.decode(AddCreditsResponse.self, from: data)
                    print("NetworkManager: Successfully added credits. New total from userInfo: \(addCreditsResponse.userInfo.credits)")
                    completion(.success(addCreditsResponse.userInfo.credits))
                } catch {
                    print("NetworkManager: Failed to decode AddCreditsResponse: \(error.localizedDescription). Data: \(String(data: data, encoding: .utf8) ?? "non-utf8 data")")
                    completion(.failure(.unexpectedResponse))
                }
            case .failure(let error):
                print("NetworkManager: Failed to add credits: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: <<< ADDED START >>>
    // Helper function to attempt to extract UserInfo from any data and update UserManager
    private static func tryExtractAndUpdateUserCredits(from data: Data?) {
        guard let data = data else { return }

        // Try to deserialize into a generic [String: Any] to look for "userInfo"
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let userInfoDict = json["userInfo"] as? [String: Any] else {
            // print("NetworkManagerHelper: No 'userInfo' key found at top level or data not JSON dict.")
            return
        }

        // Try to convert userInfoDict back to Data, then decode UserInfo struct
        guard let userInfoData = try? JSONSerialization.data(withJSONObject: userInfoDict, options: []) else {
            // print("NetworkManagerHelper: Could not re-serialize userInfo dictionary to Data.")
            return
        }

        do {
            let decodedUserInfo = try self.jsonDecoder.decode(UserInfo.self, from: userInfoData)
            print("NetworkManagerHelper: Parsed UserInfo. Credits: \(decodedUserInfo.credits) for User: \(decodedUserInfo.appleUserId)")
            UserManager.shared.updateUserCredits(credits: decodedUserInfo.credits)
        } catch {
            // print("NetworkManagerHelper: Failed to decode UserInfo from userInfo dict: \(error.localizedDescription)")
        }
    }
    // MARK: <<< ADDED END >>>
}

extension DateFormatter {
  static let iso8601Full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ" // Format with fractional seconds and timezone
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0) // Assume UTC or parse timezone from string
    formatter.locale = Locale(identifier: "en_US_POSIX") // Essential for fixed formats
    return formatter
  }()
}
// MARK: END MODIFIED FILE - Managers/NetworkManager.swift