// File: BrickAI/Managers/NetworkManager.swift
// Full Untruncated File

import Foundation
import UIKit

// Define custom errors for more specific feedback
// Added .authCodeExchangeFailed
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case dataConversionFailed
    case authenticationTokenMissing // Now refers to backend session token
    case networkRequestFailed(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized // 401 from backend
    case unexpectedResponse // Response format was not JSON as expected
    case authCodeExchangeFailed(String) // Specific error for code exchange step

    var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "The configured API endpoint URL is invalid: \(urlString)"
        case .dataConversionFailed:
            return "Failed to convert image to data format."
        case .authenticationTokenMissing:
            return "User authentication token is missing. Please log in again."
        case .networkRequestFailed(let underlyingError):
            return "Network request failed: \(underlyingError.localizedDescription)"
        case .serverError(let statusCode, let message):
             // Handle 401 Unauthorized specifically if needed elsewhere
            if statusCode == 401 { return "Unauthorized: Invalid or expired session." }
            var desc = "Server returned an error (Status Code: \(statusCode))."
            if let msg = message, !msg.isEmpty {
                desc += " Message: \(msg)"
            }
            return desc
        case .unauthorized:
             // Specifically for 401 errors, likely expired/invalid backend session token
             return "Unauthorized: Invalid or expired session."
        case .unexpectedResponse:
             return "Received an unexpected response format from the server."
        case .authCodeExchangeFailed(let message):
             return "Failed to exchange authorization code with backend: \(message)"
        }
    }
}


class NetworkManager {

    // Static property to get the base API endpoint URL from Info.plist
    private static var baseApiEndpointURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String else {
            print("Error: APIEndpointURL key not found in Info.plist.")
            return nil
        }
        // Ensure the base URL ends with a slash if it doesn't already
        let correctedUrlString = urlString.hasSuffix("/") ? urlString : urlString + "/"
        guard let url = URL(string: correctedUrlString) else {
            print("Error: APIEndpointURL value '\(correctedUrlString)' is not a valid URL.")
            return nil
        }
        return url
    }

    // Helper to construct full URL for specific endpoints
    private static func endpointURL(path: String) -> URL? {
        // Remove leading slash from path if present to avoid double slashes
        let correctedPath = path.starts(with: "/") ? String(path.dropFirst()) : path
        return baseApiEndpointURL?.appendingPathComponent(correctedPath)
    }

    // --- NEW: exchangeAuthCode function ---
    // Sends the Apple authorization code to our backend to get a session token
    static func exchangeAuthCode(
        authorizationCode: String,
        completion: @escaping (Result<String, NetworkError>) -> Void // Return backend session Token String on success
    ) {
        // 1. Get the specific endpoint URL for auth callback
        guard let authCallbackURL = endpointURL(path: "api/auth/apple/callback") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "Not Found") + "api/auth/apple/callback"
            DispatchQueue.main.async {
                completion(.failure(.invalidURL(urlString)))
            }
            return
        }
        print("NetworkManager: Attempting auth code exchange with URL: \(authCallbackURL)")

        // 2. Prepare Request Body
        let requestBody: [String: String] = ["authorizationCode": authorizationCode]
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
             print("NetworkManager: Failed to encode authorization code.")
             DispatchQueue.main.async {
                 // This is a client-side error, maybe use a more specific error type
                 completion(.failure(.authCodeExchangeFailed("Failed to encode request.")))
             }
             return
        }

        // 3. Create URLRequest
        var request = URLRequest(url: authCallbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // 4. Create and start URLSession data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // --- Process Result on Main Thread ---
            DispatchQueue.main.async {
                // Handle Network Layer Errors
                if let error = error {
                    print("NetworkManager: Auth code exchange network error: \(error.localizedDescription)")
                    completion(.failure(.networkRequestFailed(error)))
                    return
                }

                // Check HTTP Response Status
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("NetworkManager: Auth code exchange invalid response type.")
                    completion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                    return
                }

                // --- Handle Specific Status Codes ---
                print("NetworkManager: Auth code exchange received status code: \(httpResponse.statusCode)")
                guard let responseData = data else {
                     print("NetworkManager: Auth code exchange missing response data.")
                     completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Missing response data.")))
                     return
                }

                // Attempt to parse JSON regardless of status code to get error message if present
                var serverMessage: String? = nil
                var sessionToken: String? = nil

                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                         serverMessage = jsonResponse["error"] as? String ?? jsonResponse["message"] as? String
                         sessionToken = jsonResponse["sessionToken"] as? String
                    } else {
                        // Response wasn't JSON, try decoding as string
                         serverMessage = String(data: responseData, encoding: .utf8)
                         print("NetworkManager: Auth code exchange response was not valid JSON.")
                    }
                } catch {
                     serverMessage = String(data: responseData, encoding: .utf8) // Fallback to raw string
                     print("NetworkManager: Auth code exchange failed to parse response JSON: \(error.localizedDescription)")
                }


                // Check for successful status code (2xx) AND presence of session token
                if (200...299).contains(httpResponse.statusCode), let token = sessionToken {
                    print("NetworkManager: Auth code exchange successful. Received session token.")
                    completion(.success(token))
                } else {
                    // Handle failure - prioritize specific error message from JSON
                    let errorMessage = serverMessage ?? "Auth code exchange failed with status \(httpResponse.statusCode)."
                    print("NetworkManager: Auth code exchange failed: \(errorMessage)")
                    completion(.failure(.authCodeExchangeFailed(errorMessage)))
                }
            } // End DispatchQueue.main.async
        } // End URLSession Task

        // 5. Start the task
        task.resume()
    }


    // --- UPDATED: uploadImage function ---
    // Now uses the backend session token retrieved via UserManager
    static func uploadImage(
        _ image: UIImage,
        completion: @escaping (Result<String, NetworkError>) -> Void // Return URL String on success
    ) {

        // 1. Get Backend Session Token from UserManager/Keychain
        guard let token = UserManager.shared.getSessionToken() else {
            print("NetworkManager: Failed to get backend session token from UserManager.")
            DispatchQueue.main.async {
                completion(.failure(.authenticationTokenMissing))
            }
            return
        }
        // print("NetworkManager: Successfully retrieved backend session token.") // Less verbose


        // 2. Get the upload endpoint URL
        guard let endpoint = endpointURL(path: "api/upload") else {
            let urlString = (Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "Not Found") + "api/upload"
             DispatchQueue.main.async {
                 completion(.failure(.invalidURL(urlString)))
             }
            return
        }
        print("NetworkManager: Attempting image upload to URL: \(endpoint)")


        // 3. Convert UIImage to Data (same as before)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                completion(.failure(.dataConversionFailed))
            }
            return
        }

        // 4. Create URLRequest
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")

        // --- ADD AUTHORIZATION HEADER with BACKEND SESSION TOKEN ---
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // ----------------------------------------------------------

        // 5. Create and start URLSession upload task
        let task = URLSession.shared.uploadTask(with: request, from: imageData) { data, response, error in
            // --- Process Result on Main Thread ---
            DispatchQueue.main.async {
                // Handle Network Layer Errors
                if let error = error {
                     print("NetworkManager: Image upload network error: \(error.localizedDescription)")
                    completion(.failure(.networkRequestFailed(error)))
                    return
                }

                // Check HTTP Response Status
                guard let httpResponse = response as? HTTPURLResponse else {
                     print("NetworkManager: Image upload invalid response type.")
                    completion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                    return
                }

                 print("NetworkManager: Image upload received status code: \(httpResponse.statusCode)")
                 guard let responseData = data else {
                      print("NetworkManager: Image upload missing response data.")
                      completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Missing response data.")))
                      return
                 }

                // Attempt to parse JSON regardless of status code
                var serverMessage: String? = nil
                var uploadedUrl: String? = nil
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                         serverMessage = jsonResponse["error"] as? String ?? jsonResponse["message"] as? String
                         uploadedUrl = jsonResponse["url"] as? String
                    } else {
                        serverMessage = String(data: responseData, encoding: .utf8)
                        print("NetworkManager: Image upload response was not valid JSON.")
                    }
                } catch {
                     serverMessage = String(data: responseData, encoding: .utf8) // Fallback
                     print("NetworkManager: Image upload failed to parse response JSON: \(error.localizedDescription)")
                }


                // --- Handle Specific Status Codes ---
                if httpResponse.statusCode == 401 {
                     print("NetworkManager: Image upload unauthorized (401). Session likely expired.")
                     completion(.failure(.unauthorized)) // Use specific unauthorized error
                     return
                }

                // Check for successful status code (2xx) AND presence of URL
                if (200...299).contains(httpResponse.statusCode), let urlString = uploadedUrl {
                    print("NetworkManager: Image upload successful. URL: \(urlString)")
                    completion(.success(urlString)) // Pass back the URL String
                } else {
                    // Server returned an error status code (other than 401)
                    let errorMessage = serverMessage ?? "Image upload failed with status \(httpResponse.statusCode)."
                     print("NetworkManager: Image upload failed: \(errorMessage)")
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                }
            } // End DispatchQueue.main.async
        } // End URLSession Task

        // 6. Start the task
        task.resume()
    }
}