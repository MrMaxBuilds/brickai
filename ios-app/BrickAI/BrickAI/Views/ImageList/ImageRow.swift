// MARK: MODIFIED FILE - Views/ImageList/ImageRow.swift
// File: BrickAI/Views/ImageList/ImageRow.swift
// Load cached image asynchronously in onAppear to prevent blocking main thread.

import SwiftUI

// Row view for the list
struct ImageRow: View {
    let image: ImageData
    // Get ImageDataManager from environment to access cache
    @EnvironmentObject var imageDataManager: ImageDataManager

    //<-----CHANGE START------>
    // State to hold the image loaded from cache asynchronously
    @State private var cachedUIImage: UIImage? = nil
    @State private var isLoadingCache: Bool = false // Track cache loading state
    //<-----CHANGE END-------->

    var body: some View {
        let imageUrl = image.processedImageUrl ?? image.originalImageUrl
        HStack(spacing: 15) {
            Group {
                //<-----CHANGE START------>
                // 1. Display cached image from state if available
                if let loadedImage = cachedUIImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                // 2. Show placeholder while checking cache if needed (optional)
                } else if isLoadingCache {
                     ZStack { Color(.systemGray6); ProgressView().scaleEffect(0.7) } // Smaller progress for cache load
                // 3. Fallback to AsyncImage if not cached (and not loading cache)
                } else {
                //<-----CHANGE END-------->
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ZStack { Color(.systemGray5); ProgressView() } // Standard progress for network load
                        case .success(let loadedImage):
                            loadedImage.resizable().aspectRatio(contentMode: .fill).clipped()
                                //<-----CHANGE START------>
                                // Optional: Update state if AsyncImage succeeds, although onAppear should handle cache eventually
                                //.onAppear { self.cachedUIImage = loadedImage } // Might cause recursion? Be careful. Let onAppear handle cache update.
                                //<-----CHANGE END-------->
                        case .failure:
                            ZStack { Color(.systemGray5); Image(systemName: "photo.fill").resizable().aspectRatio(contentMode: .fit).padding(8).foregroundColor(.secondary) }
                        @unknown default: EmptyView()
                        }
                    }
                    //<-----CHANGE START------>
                    // Trigger network download/cache only if cache check is done and image wasn't found
                    // We do this inside the `else` block of the cache check now.
                    .onAppear {
                        // This check ensures we only trigger ensureImageIsCached if the initial cache load finished and found nothing.
                         if !isLoadingCache && cachedUIImage == nil {
                              imageDataManager.ensureImageIsCached(for: imageUrl)
                         }
                    }
                    //<-----CHANGE END-------->
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .background(Color(.systemGray6)) // Consistent background


            VStack(alignment: .leading, spacing: 4) { // Text details remain the same
                Text("Status: \(image.status.capitalized)")
                    .font(.headline).foregroundColor(statusColor(status: image.status))
                 Text(image.createdAt, style: .relative)
                    .font(.caption).foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        //<-----CHANGE START------>
        // --- Task to load cached image asynchronously ---
        .task { // .task automatically handles cancellation
             // Only attempt cache load if we haven't already loaded it
             if cachedUIImage == nil {
                  isLoadingCache = true // Indicate cache check is starting
                  // Perform synchronous cache check within an async task
                  let loadedImage = imageDataManager.getImage(for: imageUrl)
                  // Update state on main thread (implicit with @State + .task)
                  cachedUIImage = loadedImage
                  isLoadingCache = false // Indicate cache check is finished
                   // If image was found in cache, ensureImageIsCached won't be called by AsyncImage's onAppear block
             }
        }
        //<-----CHANGE END-------->

    }

    // Helper to determine status color (No changes here)
    private func statusColor(status: String) -> Color {
        switch status.uppercased() {
        case "UPLOADED", "PROCESSING": return .orange
        case "COMPLETED": return .green
        case "FAILED": return .red
        default: return .primary
        }
    }
}
// MARK: END MODIFIED FILE - Views/ImageList/ImageRow.swift
