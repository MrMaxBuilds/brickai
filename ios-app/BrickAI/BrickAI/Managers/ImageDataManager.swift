// MARK: MODIFIED FILE - Managers/ImageDataManager.swift
// File: BrickAI/Managers/ImageDataManager.swift
// Manages fetching the image list and preloading/caching image data.
// Updated prepareImageData to avoid clearing images prematurely during refresh.
// Replaced NSCache with Core Data for persistent image caching.

import Foundation
import SwiftUI // For UIImage and ObservableObject
import Combine // For ObservableObject
//<-----CHANGE START------>
import CoreData // Import Core Data
//<-----CHANGE END-------->


//<-----CHANGE START------>
// Define the Core Data Entity Name
let coreDataEntityName = "CachedImageEntity"
//<-----CHANGE END-------->

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
    //<-----CHANGE START------>
    // Removed NSCache
    // private let imageCache = NSCache<NSURL, UIImage>()

    // Core Data Persistent Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BrickAI") // Use your Core Data Model name here
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \(error), \(error.userInfo)") // Consider non-fatal error handling
            } else {
                 print("ImageDataManager: Core Data store loaded: \(storeDescription.url?.absoluteString ?? "No URL")")
                 // Ensure the context automatically merges changes saved by background contexts
                 container.viewContext.automaticallyMergesChangesFromParent = true
            }
        })
        return container
    }()

    // Convenience accessor for the main context
    private var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    //<-----CHANGE END-------->

    private let imagePreloadLimit = 20 // Configurable limit for preloading

    // --- Internal State ---
    private var fetchTask: Task<Void, Never>? = nil
    private var preloadTask: Task<Void, Never>? = nil
    //<-----CHANGE START------>
    // Track URLs currently being downloaded (using String representation for Core Data compatibility)
    private var activeDownloads = Set<String>()
    //<-----CHANGE END-------->

    init() {
        print("ImageDataManager: Initialized.")
        //<-----CHANGE START------>
        // Core Data setup happens lazily via persistentContainer access.
        // Optionally, clean up old cache items on init? (e.g., items older than X days)
        // cleanupOldCacheItems()
        //<-----CHANGE END-------->
    }

    // --- Public Methods ---

    /// Called after login or for refresh to fetch the image list and then preload images.
    func prepareImageData() {
        fetchTask?.cancel()
        preloadTask?.cancel()
        activeDownloads.removeAll()
        isPreloading = false
        preloadingProgress = 0.0

        print("ImageDataManager: prepareImageData() called. Starting fetch task.")

        self.listError = nil
        self.isLoadingList = true

        fetchTask = Task {
            do {
                let fetchedImages = try await fetchImagesWithAsyncAwait()

                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before updating images.")
                    isLoadingList = false
                    return
                }

                print("ImageDataManager: Successfully fetched \(fetchedImages.count) images.")
                self.images = fetchedImages
                self.isLoadingList = false

                triggerImagePreloading()

            } catch let error as NetworkError {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling error.")
                    isLoadingList = false
                    return
                }
                print("ImageDataManager: Error fetching images: \(error.localizedDescription ?? "Unknown error")")
                self.listError = error
                self.isLoadingList = false
            } catch {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Fetch task cancelled before handling unknown error.")
                    isLoadingList = false
                    return
                }
                print("ImageDataManager: Unknown error during image fetch: \(error)")
                self.listError = .unexpectedResponse
                self.isLoadingList = false
            }
        }
    }

    /// Retrieves an image from the Core Data cache. Returns nil if not cached.
    func getImage(for url: URL?) -> UIImage? {
        guard let urlString = url?.absoluteString else { return nil }

        //<-----CHANGE START------>
        // Fetch from Core Data
        let request = NSFetchRequest<CachedImageEntity>(entityName: coreDataEntityName)
        request.predicate = NSPredicate(format: "url == %@", urlString)
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let cachedEntity = results.first, let imageData = cachedEntity.imageData {
                 // print("ImageDataManager: Cache hit for \(urlString.suffix(20)) from Core Data.")
                 return UIImage(data: imageData)
            } else {
                 // print("ImageDataManager: Cache miss for \(urlString.suffix(20)) in Core Data.")
                 return nil
            }
        } catch {
            print("ImageDataManager: Error fetching cached image from Core Data for \(urlString): \(error)")
            return nil
        }
        //<-----CHANGE END-------->
    }

    /// Attempts to download and cache an image if not already cached or downloading.
    func ensureImageIsCached(for url: URL?) {
        guard let url = url, let urlString = url.absoluteString else { return }

        // Check cache first (using the new Core Data method)
        if getImage(for: url) != nil { return }

        //<-----CHANGE START------>
        // Check if already downloading (using String URL)
        guard !activeDownloads.contains(urlString) else { return }

        print("ImageDataManager: Explicitly caching image for URL: \(urlString)")
        activeDownloads.insert(urlString) // Use String URL
        //<-----CHANGE END-------->

        Task(priority: .background) {
            //<-----CHANGE START------>
            defer {
                // Ensure we remove from activeDownloads even if download fails
                Task { @MainActor in self.activeDownloads.remove(urlString) } // Use String URL
            }
            //<-----CHANGE END-------->
            if let image = await downloadImage(url: url) {
                 //<-----CHANGE START------>
                 // Save downloaded image to Core Data
                 saveImageToCoreData(image: image, forKey: urlString)
                 print("ImageDataManager: Successfully cached explicit request: \(urlString)")
                 //<-----CHANGE END-------->
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
        preloadTask?.cancel()
        activeDownloads.removeAll()
        isPreloading = true
        preloadingProgress = 0.0

        let imagesToPreload = Array(images.prefix(imagePreloadLimit))
        guard !imagesToPreload.isEmpty else {
            print("ImageDataManager: No images to preload.")
            isPreloading = false
            return
        }
        let totalToPreload = imagesToPreload.count
        var successfullyPreloadedCount = 0

        print("ImageDataManager: Starting preload task for up to \(totalToPreload) images.")

        preloadTask = Task(priority: .background) {
            for imageData in imagesToPreload {
                guard !Task.isCancelled else {
                    print("ImageDataManager: Preload task cancelled.")
                    break
                }

                guard let url = imageData.processedImageUrl ?? imageData.originalImageUrl else { continue }
                //<-----CHANGE START------>
                let urlString = url.absoluteString // Use String for checks
                //<-----CHANGE END-------->

                // Skip if already cached (checks Core Data now)
                if getImage(for: url) != nil {
                    print("ImageDataManager: Preload skipping already cached: \(urlString)")
                    continue
                }

                //<-----CHANGE START------>
                // Skip if already downloading (using String URL)
                guard !activeDownloads.contains(urlString) else { continue }
                activeDownloads.insert(urlString) // Mark as downloading *before* starting await
                //<-----CHANGE END-------->

                if let image = await downloadImage(url: url) {
                    guard !Task.isCancelled else {
                         print("ImageDataManager: Preload task cancelled after download, before caching \(urlString).")
                         break
                    }
                    //<-----CHANGE START------>
                    // Save to Core Data
                    saveImageToCoreData(image: image, forKey: urlString)
                    print("ImageDataManager: Preloaded and cached: \(urlString)")
                    //<-----CHANGE END-------->
                    successfullyPreloadedCount += 1
                } else {
                    print("ImageDataManager: Preload failed for: \(urlString)")
                }

                //<-----CHANGE START------>
                // Remove from active downloads set after attempt finishes (using String URL)
                Task { @MainActor in activeDownloads.remove(urlString) }
                //<-----CHANGE END-------->

                guard !Task.isCancelled else {
                     print("ImageDataManager: Preload task cancelled before progress update.")
                     break
                }
                updatePreloadProgress(current: successfullyPreloadedCount, total: totalToPreload)

            } // End loop

            Task { @MainActor in
                 let finalProgress = totalToPreload > 0 ? Double(successfullyPreloadedCount) / Double(totalToPreload) : 1.0
                 print("ImageDataManager: Preload task finished. Successfully downloaded \(successfullyPreloadedCount)/\(totalToPreload) target images. Final Progress: \(finalProgress)")
                 self.isPreloading = false
                 self.preloadingProgress = finalProgress
                 self.activeDownloads.removeAll()
            }
        }
    }

    /// Downloads a single image from a URL.
    private func downloadImage(url: URL) async -> UIImage? {
        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
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
        let progress = Double(current) / Double(total)
        self.preloadingProgress = progress
    }

    //<-----CHANGE START------>
    /// Saves an image to Core Data. Uses a background context.
    private func saveImageToCoreData(image: UIImage, forKey urlString: String) {
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
                    // Update existing entity
                     entity = existingEntity
                     print("ImageDataManager: Updating existing Core Data cache entry for \(urlString)")
                } else {
                    // Create new entity
                     entity = CachedImageEntity(context: context)
                     entity.url = urlString
                     print("ImageDataManager: Creating new Core Data cache entry for \(urlString)")
                }
                entity.imageData = imageData
                entity.lastAccessed = Date() // Optional: Track last access time

                try context.save()
                 print("ImageDataManager: Saved image to Core Data context for \(urlString).")
                 // viewContext will automatically merge these changes if configured correctly.

            } catch {
                print("ImageDataManager: Failed to save image to Core Data for key \(urlString): \(error)")
                 // Rollback changes if save fails? Context might be in inconsistent state.
                 context.rollback()
            }
        }
    }
    //<-----CHANGE END-------->


    //<-----CHANGE START------>
    /// Clears the entire Core Data image cache.
    func clearCache() {
        // Cancel any ongoing downloads/preloading
        activeDownloads.removeAll()
        preloadTask?.cancel()
        isPreloading = false

        // Perform delete on a background context
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: coreDataEntityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs // Optional: get IDs of deleted objects

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                 // Optional: Merge changes back to viewContext if needed immediately, though usually not required for delete-all
                 if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                      print("ImageDataManager: Batch deleted \(objectIDs.count) items from Core Data.")
                      // Ensure view context reflects the deletion
                      let changes = [NSDeletedObjectsKey: objectIDs]
                      NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                 } else {
                      print("ImageDataManager: Core Data image cache cleared (batch delete executed, 0 items deleted or IDs not returned).")
                 }
                try context.save() // Save the context after executing batch delete
            } catch {
                print("ImageDataManager: Failed to clear Core Data image cache: \(error)")
                context.rollback()
            }
        }
    }
    // Optional: Add a method to prune old cache items based on date or count limit
    // func cleanupOldCacheItems(maxAge: TimeInterval = 7 * 24 * 60 * 60, maxSize: Int = 100) { ... }
    //<-----CHANGE END-------->
}
// MARK: END MODIFIED FILE - Managers/ImageDataManager.swift
