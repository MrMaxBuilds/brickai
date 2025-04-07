// MARK: MODIFIED FILE - Managers/ImageDataManager.swift
// File: BrickAI/Managers/ImageDataManager.swift
// Manages fetching the image list and preloading/caching image data.
// Updated prepareImageData to avoid clearing images prematurely during refresh.

import Foundation
import SwiftUI // For UIImage and ObservableObject
import Combine // For ObservableObject

@MainActor // Ensures @Published properties are updated on the main thread
class ImageDataManager: ObservableObject {

    // --- Published Properties for UI ---
    @Published var images: [ImageData] = []
    @Published var isLoadingList: Bool = false
    @Published var listError: NetworkError? = nil
    // Optional: Progress for preloading, could be 0.0 to 1.0
    @Published var preloadingProgress: Double = 0.0
    @Published var isPreloading: Bool = false

    // --- Caching ---
    private let imageCache = NSCache<NSURL, UIImage>()
    private let imagePreloadLimit = 20 // Configurable limit for preloading

    // --- Internal State ---
    private var fetchTask: Task<Void, Never>? = nil
    private var preloadTask: Task<Void, Never>? = nil
    private var activeDownloads = Set<URL>() // Track URLs currently being downloaded

    init() {
        print("ImageDataManager: Initialized.")
        // Configure cache limits if needed (defaults are usually okay)
        // imageCache.countLimit = 50 // Example: Max 50 images in cache
        // imageCache.totalCostLimit = 1024 * 1024 * 100 // Example: Max 100MB cache size
    }

    // --- Public Methods ---

    /// Called after login or for refresh to fetch the image list and then preload images.
    func prepareImageData() {
        // Cancel existing tasks to avoid redundant work if called multiple times
        // Keep previous fetchTask cancellation, but potentially allow preload to continue?
        // For simplicity/safety, let's still cancel previous preload on a new list fetch request.
        fetchTask?.cancel()
        preloadTask?.cancel()
        // Don't clear activeDownloads here if we want downloads for older list items potentially completing?
        // Let's keep it cleared for now to ensure preload focuses on the *new* list's priority items.
        activeDownloads.removeAll()
        isPreloading = false // Reset preloading state indicators
        preloadingProgress = 0.0

        print("ImageDataManager: prepareImageData() called. Starting fetch task.")

        // MARK: <<< MODIFIED START >>>
        // Reset only error and loading state, keep existing images for smoother refresh
        // self.images = [] // REMOVED - Avoid clearing images here
        self.listError = nil
        self.isLoadingList = true
        // MARK: <<< MODIFIED END >>>

        fetchTask = Task {
            do {
                // Use await for the Result-based fetchImages
                let fetchedImages = try await fetchImagesWithAsyncAwait()

                // Check if task was cancelled before updating state
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before updating images.")
                    isLoadingList = false // Still need to turn off loading indicator
                    return
                }

                print("ImageDataManager: Successfully fetched \(fetchedImages.count) images.")
                // MARK: <<< MODIFIED START >>>
                // Update the images array only *after* successful fetch
                self.images = fetchedImages
                // Error is already nil from start of function
                // MARK: <<< MODIFIED END >>>
                self.isLoadingList = false // Finished loading list

                // Start preloading *after* list is successfully fetched and updated
                triggerImagePreloading()

            } catch let error as NetworkError {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling error.")
                    isLoadingList = false
                    return
                }
                print("ImageDataManager: Error fetching images: \(error.localizedDescription ?? "Unknown error")")
                // MARK: <<< MODIFIED START >>>
                // Don't clear images on error during refresh, keep stale data showing
                // self.images = [] // REMOVED
                // MARK: <<< MODIFIED END >>>
                self.listError = error
                self.isLoadingList = false
            } catch {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling unknown error.")
                    isLoadingList = false
                    return
                }
                print("ImageDataManager: Unknown error during image fetch: \(error)")
                // MARK: <<< MODIFIED START >>>
                // Don't clear images on error during refresh
                // self.images = [] // REMOVED
                // MARK: <<< MODIFIED END >>>
                self.listError = .unexpectedResponse // Or a more generic error
                self.isLoadingList = false
            }
        }
    }

    /// Retrieves an image from the cache. Returns nil if not cached.
    func getImage(for url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        return imageCache.object(forKey: url as NSURL)
    }

    /// Attempts to download and cache an image if not already cached or downloading.
    /// Useful for explicitly loading an image that wasn't in the top `imagePreloadLimit`.
    func ensureImageIsCached(for url: URL?) {
        guard let url = url else { return }
        // Check cache first
        if getImage(for: url) != nil { return }
        // Check if already downloading (part of preload or another explicit request)
        guard !activeDownloads.contains(url) else { return }

        print("ImageDataManager: Explicitly caching image for URL: \(url.lastPathComponent)")
        activeDownloads.insert(url)

        Task(priority: .background) { // Lower priority for explicit requests?
            defer {
                // Ensure we remove from activeDownloads even if download fails
                // Use Task to hop back to main actor for safe mutation
                Task { @MainActor in self.activeDownloads.remove(url) }
            }
            if let image = await downloadImage(url: url) {
                 // Add to cache (thread safe)
                self.imageCache.setObject(image, forKey: url as NSURL)
                print("ImageDataManager: Successfully cached explicit request: \(url.lastPathComponent)")
            }
            // No need to update progress for explicit caching
        }
    }


    // --- Private Helper Methods ---

    /// Wraps the NetworkManager's completion-handler based fetch in an async function.
    private func fetchImagesWithAsyncAwait() async throws -> [ImageData] {
        try await withCheckedThrowingContinuation { continuation in
            NetworkManager.fetchImages { result in
                switch result {
                case .success(let images):
                    continuation.resume(returning: images)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Initiates the background task to preload images.
    private func triggerImagePreloading() {
        preloadTask?.cancel() // Cancel any previous preload task
        activeDownloads.removeAll() // Clear active downloads for the new preload cycle
        isPreloading = true // Indicate preloading has started
        preloadingProgress = 0.0 // Reset progress

        // Get the list of images to preload based on the latest fetched data
        let imagesToPreload = Array(images.prefix(imagePreloadLimit))
        guard !imagesToPreload.isEmpty else {
            print("ImageDataManager: No images to preload.")
            isPreloading = false // Nothing to preload
            return
        }
        let totalToPreload = imagesToPreload.count
        var successfullyPreloadedCount = 0 // Track successful downloads *in this cycle*

        print("ImageDataManager: Starting preload task for up to \(totalToPreload) images.")

        preloadTask = Task(priority: .background) { // Run preloading in background
            for imageData in imagesToPreload {
                 // Check for cancellation before each potential download
                guard !Task.isCancelled else {
                    print("ImageDataManager: Preload task cancelled.")
                    break // Exit the loop
                }

                // Prefer processed, fallback to original
                guard let url = imageData.processedImageUrl ?? imageData.originalImageUrl else {
                    continue // Skip if no valid URL for this item
                }

                // Skip if already cached (This is the key part for refresh logic)
                if getImage(for: url) != nil {
                    print("ImageDataManager: Preload skipping already cached: \(url.lastPathComponent)")
                    // Don't increment successfullyPreloadedCount here, as we didn't download it *now*
                    // Only count actual downloads within this task towards progress? Or count skips too?
                    // Let's adjust progress based on iteration / total items targeted for check.
                    // Alternative: base progress on actual downloads initiated/completed.
                    // Let's keep simple progress: items processed / total items to check.
                    // successfullyPreloadedCount += 1 // If counting skips as progress
                    // updatePreloadProgress(current: successfullyPreloadedCount, total: totalToPreload)
                    continue // Move to the next image
                }

                // Skip if already downloading (shouldn't happen if activeDownloads was cleared, but check anyway)
                guard !activeDownloads.contains(url) else { continue }

                activeDownloads.insert(url) // Mark as downloading *before* starting await
                if let image = await downloadImage(url: url) {
                     // Check for cancellation *after* download but *before* caching
                    guard !Task.isCancelled else {
                         print("ImageDataManager: Preload task cancelled after download, before caching \(url.lastPathComponent).")
                         break
                    }
                    // Add to cache (NSCache is thread safe)
                    imageCache.setObject(image, forKey: url as NSURL)
                    print("ImageDataManager: Preloaded and cached: \(url.lastPathComponent)")
                    successfullyPreloadedCount += 1 // Count successful downloads
                } else {
                    // Download failed (error already logged by downloadImage)
                    print("ImageDataManager: Preload failed for: \(url.lastPathComponent)")
                    // Don't increment success count on failure
                }
                 // Remove from active downloads set after attempt finishes
                 // Use Task @MainActor to safely modify activeDownloads
                Task { @MainActor in activeDownloads.remove(url) }


                // Check for cancellation before updating progress
                guard !Task.isCancelled else {
                     print("ImageDataManager: Preload task cancelled before progress update.")
                     break
                }
                 // Update progress on main thread based on successful downloads
                updatePreloadProgress(current: successfullyPreloadedCount, total: totalToPreload)

            } // End loop

             // Final state update after loop finishes or breaks
            Task { @MainActor in
                 // Calculate final progress based on successful downloads vs total targeted (could be < 1.0 if some failed/skipped)
                 let finalProgress = totalToPreload > 0 ? Double(successfullyPreloadedCount) / Double(totalToPreload) : 1.0
                 print("ImageDataManager: Preload task finished. Successfully downloaded \(successfullyPreloadedCount)/\(totalToPreload) target images. Final Progress: \(finalProgress)")
                 self.isPreloading = false // Mark preloading as complete
                 self.preloadingProgress = finalProgress // Set final progress
                 // self.preloadingProgress = 1.0 // Alternative: Always set to 1.0 on completion
                 self.activeDownloads.removeAll() // Ensure clear at the very end
            }
        }
    }

    /// Downloads a single image from a URL.
    private func downloadImage(url: URL) async -> UIImage? {
        do {
            // Use default URLSession; configure cache policy if needed
            // Consider .reloadIgnoringLocalCacheData if backend images might update under same URL? Unlikely for S3.
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad) // Standard policy
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("ImageDataManager: Failed to download image from \(url.lastPathComponent) - Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            guard let image = UIImage(data: data) else {
                 print("ImageDataManager: Failed to create UIImage from downloaded data for \(url.lastPathComponent)")
                 return nil
            }
            return image
        } catch {
             // Handle cancellation error specifically
            if (error as? URLError)?.code == .cancelled {
                 print("ImageDataManager: Download cancelled for \(url.lastPathComponent).")
            } else {
                 print("ImageDataManager: Error downloading image \(url.lastPathComponent): \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Updates the preloading progress (ensures it runs on main thread).
    private func updatePreloadProgress(current: Int, total: Int) {
        guard total > 0 else { return }
        // Calculate progress based on successful downloads vs total items targeted
        let progress = Double(current) / Double(total)
        self.preloadingProgress = progress
        // print("ImageDataManager: Preload progress: \(progress * 100)%") // Optional verbose log
    }

    // Optional: Method to clear cache if needed (e.g., on logout)
    func clearCache() {
        imageCache.removeAllObjects()
        activeDownloads.removeAll() // Cancel any in-flight downloads associated with cache
        isPreloading = false
        preloadTask?.cancel() // Cancel the preload task itself
        print("ImageDataManager: Image cache cleared.")
    }
}
// MARK: END MODIFIED FILE - Managers/ImageDataManager.swift