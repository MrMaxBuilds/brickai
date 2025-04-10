// MARK: MODIFIED FILE - Managers/ImageDataManager.swift
// File: BrickAI/Managers/ImageDataManager.swift
// Manages fetching the image list and preloading/caching image data.
// Updated prepareImageData to avoid clearing images prematurely during refresh.
// Replaced NSCache with Core Data for persistent image caching.
// Fixed optional binding error for url.absoluteString.
// <-----CHANGE START------>
// Added background polling timer.
// <-----CHANGE END-------->

import Foundation
import SwiftUI // For UIImage and ObservableObject
import Combine // For ObservableObject
import CoreData // Import Core Data


// Define the Core Data Entity Name
let coreDataEntityName = "CachedImageEntity"

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
    // Core Data Persistent Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BrickAI") // Use your Core Data Model name here
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)") // Consider non-fatal error handling
            } else {
                 print("ImageDataManager: Core Data store loaded: \(storeDescription.url?.absoluteString ?? "No URL")")
                 container.viewContext.automaticallyMergesChangesFromParent = true
            }
        })
        return container
    }()

    // Convenience accessor for the main context
    private var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private let imagePreloadLimit = 20 // Configurable limit for preloading

    // --- Internal State ---
    private var fetchTask: Task<Void, Never>? = nil
    private var preloadTask: Task<Void, Never>? = nil
    // Track URLs currently being downloading (using String representation for Core Data compatibility)
    private var activeDownloads = Set<String>()
    // <-----CHANGE START------>
    // Timer for background polling
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 5.0 // 5 seconds
    // <-----CHANGE END-------->

    init() {
        print("ImageDataManager: Initialized.")
        // <-----CHANGE START------>
        // Start polling when the manager is initialized.
        // This assumes the manager is created when needed (e.g., at app launch or login).
        startPolling()
        // Initial fetch is triggered by the first timer fire, or can be called explicitly here if needed immediately:
        // prepareImageData()
        // <-----CHANGE END-------->
    }

    // --- Public Methods ---

    /// Called by timer or for manual refresh to fetch the image list and then preload images.
    func prepareImageData() {
        // Don't cancel ongoing tasks if called rapidly (e.g., by timer + manual refresh)
        // unless current fetch is truly stale. Let existing fetch/preload complete.
        // Only start a new fetch if not already loading the list.
        guard !isLoadingList else {
             print("ImageDataManager: prepareImageData() called, but already loading list. Ignoring.")
             return
        }

        // Cancel previous *specific* tasks if needed, but generally let them run unless state demands cancellation.
        // fetchTask?.cancel() // Be cautious cancelling ongoing operations frequently
        // preloadTask?.cancel()

        // activeDownloads.removeAll() // Don't clear downloads if a preload might still be useful
        isPreloading = false // Reset preload state indicators for the new fetch cycle
        preloadingProgress = 0.0

        print("ImageDataManager: prepareImageData() called. Starting fetch task.")

        self.listError = nil
        self.isLoadingList = true // Mark as loading *before* starting the task

        fetchTask = Task {
            do {
                let fetchedImages = try await fetchImagesWithAsyncAwait()

                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before updating images.")
                    // Ensure isLoadingList is reset even if cancelled
                    if isLoadingList { isLoadingList = false }
                    return
                }

                print("ImageDataManager: Successfully fetched \(fetchedImages.count) images.")
                // Only update images and trigger preload if the data has actually changed?
                // For simplicity, always update for now. Add comparison logic if needed.
                self.images = fetchedImages
                self.isLoadingList = false // Mark as finished loading

                triggerImagePreloading()

            } catch let error as NetworkError {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling error.")
                    if isLoadingList { isLoadingList = false }
                    return
                }
                print("ImageDataManager: Error fetching images: \(error.localizedDescription)")
                self.listError = error
                self.isLoadingList = false // Mark as finished loading (with error)
            } catch {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling unknown error.")
                    if isLoadingList { isLoadingList = false }
                    return
                }
                print("ImageDataManager: Unknown error during image fetch: \(error)")
                self.listError = .unexpectedResponse
                self.isLoadingList = false // Mark as finished loading (with error)
            }
        }
    }

    // <-----CHANGE START------>
    /// Starts the background polling timer.
    func startPolling() {
        print("ImageDataManager: Starting polling timer with interval \(pollingInterval) seconds.")
        // Invalidate existing timer first
        stopPolling()
        // Schedule new timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
             print("ImageDataManager: Polling timer fired.")
             // Call prepareImageData on the main actor instance
             self?.prepareImageData()
        }
        // Fire immediately on start? Optional.
        // pollingTimer?.fire() // Uncomment to fetch immediately when polling starts
    }

    /// Stops the background polling timer.
    func stopPolling() {
        if pollingTimer != nil {
             print("ImageDataManager: Stopping polling timer.")
             pollingTimer?.invalidate()
             pollingTimer = nil
        }
    }
    // <-----CHANGE END-------->


    /// Retrieves an image from the Core Data cache. Returns nil if not cached.
    func getImage(for url: URL?) -> UIImage? {
        // First, safely unwrap the optional URL
        guard let unwrappedUrl = url else { return nil }
        // Now that url is unwrapped, get the non-optional absoluteString
        let urlString = unwrappedUrl.absoluteString

        // Fetch from Core Data
        let request = NSFetchRequest<CachedImageEntity>(entityName: coreDataEntityName)
        request.predicate = NSPredicate(format: "url == %@", urlString)
        request.fetchLimit = 1

        do {
            // Fetch synchronously on the current thread (main actor)
            let results = try viewContext.fetch(request)
            if let cachedEntity = results.first, let imageData = cachedEntity.imageData {
                 // print("ImageDataManager: Cache hit for \(urlString)") // Verbose
                 return UIImage(data: imageData)
            } else {
                 // print("ImageDataManager: Cache miss for \(urlString)") // Verbose
                 return nil
            }
        } catch {
            print("ImageDataManager: Error fetching cached image from Core Data for \(urlString): \(error)")
            return nil
        }
    }

    /// Attempts to download and cache an image if not already cached or downloading.
    func ensureImageIsCached(for url: URL?) {
        // First, safely unwrap the optional URL
        guard let unwrappedUrl = url else { return }
        // Now that url is unwrapped, get the non-optional absoluteString
        let urlString = unwrappedUrl.absoluteString

        // Check cache first (using the new Core Data method)
        if getImage(for: unwrappedUrl) != nil { return }

        // Check if already downloading (using String URL)
        // Need to access activeDownloads carefully if this can be called from non-main thread
        // Since it's called from ImageRow's .task (MainActor), it should be safe.
        guard !activeDownloads.contains(urlString) else { return }

        print("ImageDataManager: Explicitly caching image for URL: \(urlString)")
        activeDownloads.insert(urlString) // Use String URL

        Task(priority: .background) {
            defer {
                // Ensure we remove from activeDownloads even if download fails
                Task { @MainActor in self.activeDownloads.remove(urlString) } // Use String URL
            }
            // Use the unwrapped URL for downloading
            if let image = await downloadImage(url: unwrappedUrl) {
                 // Save downloaded image to Core Data (on background thread)
                 saveImageToCoreData(image: image, forKey: urlString)
                 print("ImageDataManager: Successfully cached explicit request: \(urlString)")
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
                // Safely unwrap the URL first
                guard let url = imageData.processedImageUrl ?? imageData.originalImageUrl else {
                    continue // Skip if no valid URL for this item
                }
                // Get the non-optional string
                let urlString = url.absoluteString

                // Skip if already cached (checks Core Data now using the unwrapped URL)
                // Perform cache check within the task's actor context (MainActor here)
                if getImage(for: url) != nil {
                    // print("ImageDataManager: Preload skipping already cached: \(urlString)") // Verbose
                    continue // Move to the next image
                }

                // Skip if already downloading (using String URL)
                // Accessing activeDownloads needs to be safe if Task is not on MainActor
                // Since ImageDataManager is @MainActor, this access is safe.
                guard !activeDownloads.contains(urlString) else { continue }

                activeDownloads.insert(urlString) // Mark as downloading *before* starting await
                // Use the unwrapped URL for downloading
                if let image = await downloadImage(url: url) {
                    // Check for cancellation *after* download but *before* caching
                    guard !Task.isCancelled else {
                         print("ImageDataManager: Preload task cancelled after download, before caching \(urlString).")
                         break
                    }
                    // Save to Core Data (on background thread)
                    saveImageToCoreData(image: image, forKey: urlString)
                    print("ImageDataManager: Preloaded and cached: \(urlString)")
                    successfullyPreloadedCount += 1 // Count successful downloads
                } else {
                    // Download failed (error already logged by downloadImage)
                    print("ImageDataManager: Preload failed for: \(urlString)")
                    // Don't increment success count on failure
                }
                 // Remove from active downloads set after attempt finishes (using String URL)
                Task { @MainActor in activeDownloads.remove(urlString) }


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
                 // Calculate final progress based on successful downloads vs total targeted
                 let finalProgress = totalToPreload > 0 ? Double(successfullyPreloadedCount) / Double(totalToPreload) : 1.0
                 print("ImageDataManager: Preload task finished. Successfully downloaded \(successfullyPreloadedCount)/\(totalToPreload) target images. Final Progress: \(finalProgress)")
                 self.isPreloading = false // Mark preloading as complete
                 self.preloadingProgress = finalProgress // Set final progress
                 self.activeDownloads.removeAll() // Ensure clear at the very end
            }
        }
    }

    /// Downloads a single image from a URL. Takes a non-optional URL.
    private func downloadImage(url: URL) async -> UIImage? { // Expects non-optional URL
        do {
            // Use default URLSession; configure cache policy if needed
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
        // Ensure update happens on MainActor
        // Task { @MainActor in self.preloadingProgress = progress } // Already on MainActor
        self.preloadingProgress = progress
    }

    /// Saves an image to Core Data. Uses a background context. Takes a non-optional String key.
    func saveImageToCoreData(image: UIImage, forKey urlString: String) { // Expects non-optional String key
        // Use PNG representation for potentially better quality/lossless, or JPEG for space saving
        guard let imageData = image.pngData() else { // Or image.jpegData(compressionQuality: 0.8)
            print("ImageDataManager: Failed to get PNG data for image \(urlString)")
            return
        }

        // Perform Core Data operations on a background context
        let context = persistentContainer.newBackgroundContext()
        context.perform { // Use perform to ensure operations are on the context's queue
            let request = NSFetchRequest<CachedImageEntity>(entityName: coreDataEntityName)
            request.predicate = NSPredicate(format: "url == %@", urlString)
            request.fetchLimit = 1

            do {
                let results = try context.fetch(request)
                let entity: CachedImageEntity
                if let existingEntity = results.first {
                     entity = existingEntity
                     // print("ImageDataManager: Updating existing Core Data cache entry for \(urlString)") // Verbose
                } else {
                     entity = CachedImageEntity(context: context)
                     entity.url = urlString
                     // print("ImageDataManager: Creating new Core Data cache entry for \(urlString)") // Verbose
                }
                entity.imageData = imageData
                entity.lastAccessed = Date() // Optional: Track last access time

                try context.save()
                 // print("ImageDataManager: Saved image to Core Data context for \(urlString).") // Verbose

            } catch {
                print("ImageDataManager: Failed to save image to Core Data for key \(urlString): \(error)")
                 context.rollback() // Rollback changes on error
            }
        }
    }


    /// Clears the entire Core Data image cache.
    func clearCache() {
        //<-----CHANGE START------>
        // Stop polling before clearing cache
        stopPolling()
        //<-----CHANGE END-------->
        // Cancel any ongoing downloads/preloading
        activeDownloads.removeAll()
        preloadTask?.cancel()
        isPreloading = false

        // Perform delete on a background context
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: coreDataEntityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                 if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                      print("ImageDataManager: Batch deleted \(objectIDs.count) items from Core Data.")
                      // Merge changes back to the main context
                      let changes = [NSDeletedObjectsKey: objectIDs]
                      NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                 } else {
                      print("ImageDataManager: Core Data image cache cleared (batch delete executed, 0 items deleted or IDs not returned).")
                 }
                // Save the context after successful batch delete
                 // No explicit save needed after batch delete if context is just for this operation?
                 // However, saving ensures consistency if other changes were pending. Let's keep it.
                 // try context.save() // Redundant? Batch delete persists directly. Removed.

            } catch {
                print("ImageDataManager: Failed to clear Core Data image cache: \(error)")
                // Rollback is implicitly handled by not saving if execute fails
                // context.rollback() // Not needed here
            }
        }
    }
}
// MARK: END MODIFIED FILE - Managers/ImageDataManager.swift