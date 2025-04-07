// MARK: MODIFIED FILE - Views/ImageDetailView.swift
// File: BrickAI/Views/ImageDetailView.swift
// Updated to use ImageDataManager cache

import SwiftUI

struct ImageDetailView: View {
    let image: ImageData
    // MARK: <<< ADDED START >>>
    // Get ImageDataManager from environment
    @EnvironmentObject var imageDataManager: ImageDataManager
    // MARK: <<< ADDED END >>>

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {

                // MARK: <<< MODIFIED START >>>
                // Check cache first
                let imageUrl = image.processedImageUrl ?? image.originalImageUrl
                let cachedImage = imageDataManager.getImage(for: imageUrl)

                Group { // Use Group to apply frame/modifiers consistently
                    if let loadedImage = cachedImage {
                        // Display cached image
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFit()

                    } else {
                        // Fallback to AsyncImage
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 300) // Maintain height during load
                            case .success(let loadedImage):
                                loadedImage
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                VStack {
                                    Image(systemName: "photo.fill.on.rectangle.fill") // More descriptive icon
                                         .font(.largeTitle)
                                         .foregroundColor(.secondary)
                                    Text("Failed to load image")
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: 300) // Maintain height on failure
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
                .frame(maxWidth: .infinity) // Center AsyncImage/Image content horizontally
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.horizontal) // Add horizontal padding if image is narrower than screen
                // MARK: <<< MODIFIED END >>>


                // Details Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status: \(image.status.capitalized)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Divider() // Add divider

                    if let prompt = image.prompt, !prompt.isEmpty {
                        Text("Prompt")
                            .font(.headline)
                        Text(prompt)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Divider()
                    }

                    Text("Uploaded")
                        .font(.headline)
                    // Use formatted styles for better presentation
                    Text(image.createdAt.formatted(date: .long, time: .shortened))
                         .font(.body)
                         .foregroundColor(.secondary)
                }
                .padding(.horizontal) // Padding for text details

                Spacer()
            }
            .padding(.vertical) // Vertical padding for the outer VStack
        }
        .navigationTitle("Image Details")
        .navigationBarTitleDisplayMode(.inline)
         // MARK: <<< ADDED START >>>
         // Inject the environment object needed by this view
         .environmentObject(imageDataManager)
         // MARK: <<< ADDED END >>>
    }
}

// MARK: END MODIFIED FILE - Views/ImageDetailView.swift