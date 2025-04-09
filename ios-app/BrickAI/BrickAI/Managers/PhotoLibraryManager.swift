// MARK: ADDED FILE - Managers/PhotoLibraryManager.swift
// File: BrickAI/Managers/PhotoLibraryManager.swift
// Handles downloading (if necessary) and saving images to the Photo Library.

import Foundation
import UIKit
import Photos // Import Photos framework

// Define specific errors for this manager
enum PhotoLibraryError: Error, LocalizedError {
    case invalidURL
    case imageNotFoundOrDownloadFailed
    case photoLibraryAccessDenied
    case saveFailed(Error?) // Optional underlying error from Photos framework

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided image URL was invalid."
        case .imageNotFoundOrDownloadFailed:
            return "Could not retrieve or download the image."
        case .photoLibraryAccessDenied:
            return "Photo Library access denied. Please grant permission in Settings."
        case .saveFailed(let underlying):
            let baseMessage = "Failed to save image to Photo Library."
            if let nsError = underlying as NSError? {
                return "\(baseMessage) Error code: \(nsError.code). \(nsError.localizedDescription)"
            }
            return baseMessage
        }
    }
}

@MainActor // Use MainActor if methods update UI state indirectly (e.g., via @State vars in views)
class PhotoLibraryManager: ObservableObject {

    // Helper object to handle Photo Library save completion
    private lazy var photoLibrarySaver = PhotoLibrarySaveHelper()

    // --- Public API ---

    /// Saves a pre-loaded UIImage directly to the Photo Library.
    /// Handles permission checks.
    func saveImage(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        print("PhotoLibraryManager: Initiating save for pre-loaded image.")
        checkPermissionAndSave(image: image, completion: completion)
    }

    /// Downloads an image from a URL (if not already available) and saves it to the Photo Library.
    /// Handles permission checks.
    func downloadAndSaveImage(url: URL?, imageDataManager: ImageDataManager, completion: @escaping (Result<Void, Error>) -> Void) {
         guard let targetUrl = url else {
             completion(.failure(PhotoLibraryError.invalidURL))
             return
         }
         print("PhotoLibraryManager: Initiating download & save for URL: \(targetUrl.absoluteString)")

         // 1. Check cache via ImageDataManager
         if let cachedImage = imageDataManager.getImage(for: targetUrl) {
              print("PhotoLibraryManager: Image found in cache. Proceeding to save.")
              checkPermissionAndSave(image: cachedImage, completion: completion)
              return
         }

         // 2. Not in cache, attempt download
         print("PhotoLibraryManager: Image not in cache. Attempting download...")
         Task(priority: .userInitiated) { // Use userInitiated priority for responsive save action
             if let downloadedImage = await self.downloadImage(url: targetUrl) {
                 print("PhotoLibraryManager: Download successful. Proceeding to save.")
                 // Also cache the downloaded image
                 imageDataManager.saveImageToCoreData(image: downloadedImage, forKey: targetUrl.absoluteString)
                 // Save to library
                 self.checkPermissionAndSave(image: downloadedImage, completion: completion)
             } else {
                  print("PhotoLibraryManager: Download failed.")
                  completion(.failure(PhotoLibraryError.imageNotFoundOrDownloadFailed))
             }
         }
    }


    // --- Private Helpers ---

    /// Checks Photo Library permission and proceeds to save if authorized.
    private func checkPermissionAndSave(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                    if newStatus == .authorized || newStatus == .limited {
                         self?.saveToLibrary(image: image, completion: completion)
                    } else {
                         completion(.failure(PhotoLibraryError.photoLibraryAccessDenied))
                    }
                }
            case .restricted, .denied:
                completion(.failure(PhotoLibraryError.photoLibraryAccessDenied))
            case .authorized, .limited:
                saveToLibrary(image: image, completion: completion)
            @unknown default:
                completion(.failure(PhotoLibraryError.photoLibraryAccessDenied))
        }
    }

    /// Performs the actual save operation using the helper.
    private func saveToLibrary(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        print("PhotoLibraryManager: Saving image using helper...")
        photoLibrarySaver.saveImage(image, completion: completion)
    }

    /// Downloads a single image from a URL. (Copied basic implementation - could be shared utility)
    private func downloadImage(url: URL) async -> UIImage? {
        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad) // Use cache if available
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                 print("PhotoLibraryManager: Download failed - Status: \((response as? HTTPURLResponse)?.statusCode ?? 0) for \(url.lastPathComponent)")
                return nil
            }
            guard let image = UIImage(data: data) else {
                 print("PhotoLibraryManager: Failed to create UIImage from data for \(url.lastPathComponent)")
                 return nil
            }
             print("PhotoLibraryManager: Image downloaded successfully from \(url.lastPathComponent).")
            return image
        } catch {
             if (error as? URLError)?.code == .cancelled {
                 print("PhotoLibraryManager: Download cancelled for \(url.lastPathComponent).")
             } else {
                 print("PhotoLibraryManager: Error downloading \(url.lastPathComponent): \(error.localizedDescription)")
             }
            return nil
        }
    }
}

// Helper class to handle the UIImageWriteToSavedPhotosAlbum completion selector
// (Remains the same as before)
private class PhotoLibrarySaveHelper: NSObject {
    private var completionHandler: ((Result<Void, Error>) -> Void)?

    func saveImage(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        self.completionHandler = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
             print("PhotoLibrarySaveHelper: Error saving image: \(error.localizedDescription)")
             if (error as NSError).code == PHPhotosError.accessRestricted.rawValue || (error as NSError).code == PHPhotosError.accessUserDenied.rawValue {
                  completionHandler?(.failure(PhotoLibraryError.photoLibraryAccessDenied))
             } else {
                  completionHandler?(.failure(PhotoLibraryError.saveFailed(error)))
             }
        } else {
            print("PhotoLibrarySaveHelper: Image saved successfully.")
            completionHandler?(.success(()))
        }
        completionHandler = nil
    }
}
// MARK: END ADDED FILE - Managers/PhotoLibraryManager.swift