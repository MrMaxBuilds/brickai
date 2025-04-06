import Foundation
import UIKit

// Define custom errors for more specific feedback
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case dataConversionFailed
    case authenticationTokenMissing
    case networkRequestFailed(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized // Added for 401 specifically

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
            if statusCode == 401 { return "Unauthorized: Invalid or expired token." }
            var desc = "Server returned an error (Status Code: \(statusCode))."
            if let msg = message, !msg.isEmpty {
                desc += " Message: \(msg)"
            }
            return desc
        case .unauthorized:
             return "Unauthorized: Invalid or expired token."
        }
    }
}


class NetworkManager {

    // Static property to get the endpoint URL from Info.plist
    private static var apiEndpointURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String else {
            print("Error: APIEndpointURL key not found in Info.plist.")
            return nil
        }
        guard let url = URL(string: urlString) else {
            print("Error: APIEndpointURL value '\(urlString)' is not a valid URL.")
            return nil
        }
        return url
    }

    // --- UPDATED: uploadImage function ---
    // No longer needs identityToken parameter, retrieves it internally
    static func uploadImage(
        _ image: UIImage,
        completion: @escaping (Result<String, NetworkError>) -> Void // Return URL String on success
    ) {

        // 1. Get Authentication Token from UserManager/Keychain
        // Assumes UserManager.shared provides access
        guard let token = UserManager.shared.getIdentityToken() else {
            print("NetworkManager: Failed to get identity token from UserManager.")
            DispatchQueue.main.async {
                completion(.failure(.authenticationTokenMissing))
            }
            return
        }
        // Optional: Add logging for token retrieval success (but don't log the token itself)
        // print("NetworkManager: Successfully retrieved identity token.")


        // 2. Get the endpoint URL
        guard let endpoint = apiEndpointURL else {
            // Ensure completion handler is called on the main thread for UI updates
             DispatchQueue.main.async {
                 completion(.failure(.invalidURL(Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "Not Found")))
             }
            return
        }

        // 3. Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                completion(.failure(.dataConversionFailed))
            }
            return
        }

        // 4. Create URLRequest
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type") // Adjust if needed
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")

        // --- ADD AUTHORIZATION HEADER ---
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // --------------------------------

        // 5. Create and start URLSession upload task
        let task = URLSession.shared.uploadTask(with: request, from: imageData) { data, response, error in
            // --- Process Result on Main Thread ---
            DispatchQueue.main.async {
                // Handle Network Layer Errors
                if let error = error {
                    completion(.failure(.networkRequestFailed(error)))
                    return
                }

                // Check HTTP Response Status
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                    return
                }

                // --- Handle Specific Status Codes ---
                if httpResponse.statusCode == 401 {
                     completion(.failure(.unauthorized))
                     return
                }

                // Check for successful status code (2xx)
                if (200...299).contains(httpResponse.statusCode) {
                    // Try to parse the success response JSON to get the URL
                    guard let responseData = data else {
                        completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Missing response data on success.")))
                        return
                    }
                    do {
                        // Attempt to deserialize JSON and extract the 'url' field
                        if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                           let urlString = jsonResponse["url"] as? String {
                            completion(.success(urlString)) // Pass back the URL String
                        } else {
                            // The response was successful (2xx) but the JSON format was not as expected
                            completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Invalid success response format.")))
                        }
                    } catch {
                        // JSON deserialization failed
                         completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to parse success response: \(error.localizedDescription)")))
                    }

                } else {
                    // Server returned an error status code (other than 401)
                    var serverMessage: String? = nil
                    if let responseData = data {
                        // Try to parse error JSON message if available
                         if let jsonResponse = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                            let errorMsg = jsonResponse["error"] as? String {
                             serverMessage = errorMsg // Use specific error message from JSON
                         } else {
                             // Fallback to raw string if JSON parsing fails or no "error" field
                             serverMessage = String(data: responseData, encoding: .utf8)
                         }
                    }
                    // Include the parsed/raw error message if available
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: serverMessage)))
                }
            } // End DispatchQueue.main.async
        } // End URLSession Task

        // 6. Start the task
        task.resume()
    }
}
