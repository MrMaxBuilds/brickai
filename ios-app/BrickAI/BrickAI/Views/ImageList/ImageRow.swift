// MARK: ADDED FILE - Views/ImageList/ImageRow.swift
// File: BrickAI/Views/ImageList/ImageRow.swift
// Row view for the image list, extracted from ImageListView.swift

import SwiftUI

// Row view for the list
struct ImageRow: View {
    let image: ImageData
    // Get ImageDataManager from environment to access cache
    @EnvironmentObject var imageDataManager: ImageDataManager

    var body: some View {
        HStack(spacing: 15) {
            // Check cache first
            let imageUrl = image.processedImageUrl ?? image.originalImageUrl
            let cachedImage = imageDataManager.getImage(for: imageUrl)

            Group { // Use Group to apply frame consistently
                if let loadedImage = cachedImage {
                    // Use cached image directly
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill) // Use fill for consistent size
                        // Frame applied below by Group
                        .clipped() // Clip to bounds

                } else {
                    // Fallback to AsyncImage if not cached
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ZStack { // Add background during loading
                                Color(.systemGray5)
                                ProgressView()
                            }
                            // Frame applied by Group

                        case .success(let loadedImage):
                            loadedImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                // Frame applied by Group
                                .clipped()

                        case .failure:
                            ZStack { // Add background on failure
                                Color(.systemGray5)
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8) // Add padding to the SF Symbol
                                    .foregroundColor(.secondary)
                            }
                            // Frame applied by Group

                        @unknown default:
                            EmptyView()
                        }
                    }
                     // Trigger explicit cache load if image wasn't preloaded
                     .onAppear {
                          imageDataManager.ensureImageIsCached(for: imageUrl)
                     }
                }
            }
            .frame(width: 60, height: 60) // Apply frame here
            .cornerRadius(8) // Apply cornerRadius here
             .background(Color(.systemGray6)) // Add background for consistency


            VStack(alignment: .leading, spacing: 4) { // Added spacing
                Text("Status: \(image.status.capitalized)")
                    .font(.headline)
                    .foregroundColor(statusColor(status: image.status))
                if let prompt = image.prompt, !prompt.isEmpty {
                     Text(prompt) // Removed "Prompt:" prefix for cleaner look
                         .font(.subheadline)
                         .foregroundColor(.secondary)
                         .lineLimit(1)
                         .truncationMode(.tail) // Ensure truncation is clear
                }
                 // Convert Date to String using formatted API for relative style
                 Text(image.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer() // Push content to left
        }
        .padding(.vertical, 8) // Increased vertical padding for better spacing
    }

    // Helper to determine status color
    private func statusColor(status: String) -> Color {
        switch status.uppercased() {
        case "UPLOADED", "PROCESSING": return .orange
        case "COMPLETED": return .green
        case "FAILED": return .red
        default: return .primary
        }
    }
}
// MARK: END ADDED FILE - Views/ImageList/ImageRow.swift