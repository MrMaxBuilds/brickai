// File: BrickAI/Views/ImageDetailView.swift
// Full Untruncated File - Reviewed, Formatted

import SwiftUI

struct ImageDetailView: View {
    let image: ImageData

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {

                AsyncImage(url: image.processedImageUrl ?? image.originalImageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity) // Allow ProgressView to center
                            .frame(height: 300)
                    case .success(let loadedImage):
                        loadedImage
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.horizontal) // Add horizontal padding if image is narrower than screen
                    case .failure:
                        VStack {
                            Image(systemName: "photo.fill.on.rectangle.fill") // More descriptive icon
                                 .font(.largeTitle)
                                 .foregroundColor(.secondary)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity) // Center AsyncImage content horizontally

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
    }
}

// ImageDetailView_Previews remains the same
struct ImageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
             ImageDetailView(image: ImageData.previewData[0])
        }
    }
}
