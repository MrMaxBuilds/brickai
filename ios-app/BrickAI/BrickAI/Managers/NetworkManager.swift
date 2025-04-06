//
//  NetworkError.swift
//  BrickAI
//
//  Created by Max U on 4/5/25.
//


import Foundation
import UIKit // Required for UIImage

// Define custom errors for more specific feedback
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case dataConversionFailed
    case networkRequestFailed(Error)
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "The configured API endpoint URL is invalid: \(urlString)"
        case .dataConversionFailed:
            return "Failed to convert image to data format."
        case .networkRequestFailed(let underlyingError):
            return "Network request failed: \(underlyingError.localizedDescription)"
        case .serverError(let statusCode, let message):
            var desc = "Server returned an error (Status Code: \(statusCode))."
            if let msg = message, !msg.isEmpty {
                desc += " Message: \(msg)"
            }
            return desc
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

    // Static function to upload the image
    // Uses a Result type in the completion handler for clear success/failure reporting
    static func uploadImage(_ image: UIImage, completion: @escaping (Result<Void, NetworkError>) -> Void) {

        // 1. Get the endpoint URL
        guard let endpoint = apiEndpointURL else {
            // Ensure completion handler is called on the main thread for UI updates
            DispatchQueue.main.async {
                completion(.failure(.invalidURL(Bundle.main.object(forInfoDictionaryKey: "APIEndpointURL") as? String ?? "Not Found")))
            }
            return
        }

        // 2. Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                completion(.failure(.dataConversionFailed))
            }
            return
        }

        // 3. Create URLRequest
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type") // Adjust if needed
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")
        // Add other headers if required (e.g., Authorization)
        // request.setValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")

        // 4. Create and start URLSession upload task
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
                    // This case is less common with uploadTask but good to check
                    completion(.failure(.serverError(statusCode: 0, message: "Invalid response type")))
                    return
                }

                // Check for successful status code (2xx)
                if (200...299).contains(httpResponse.statusCode) {
                    // Successful upload
                    completion(.success(())) // Use empty tuple Void for success
                } else {
                    // Server returned an error status code
                    var serverMessage: String? = nil
                    if let responseData = data {
                        serverMessage = String(data: responseData, encoding: .utf8)
                    }
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: serverMessage)))
                }
            } // End DispatchQueue.main.async
        } // End URLSession Task

        // 5. Start the task
        task.resume()
    }
}