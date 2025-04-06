//
//  ImageDetailView.swift
//  BrickAI
//
//  Created by Max U on 4/6/25.
//


// File: BrickAI/Views/ImageDetailView.swift
// Full Untruncated File - No changes needed

import SwiftUI

struct ImageDetailView: View {
    let image: ImageData // Accepts ImageData with Int ID

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                AsyncImage(url: image.processedImageUrl ?? image.originalImageUrl) { phase in
                    // Placeholder/Image logic...
                    if let img = phase.image { img.resizable().scaledToFit().cornerRadius(10).shadow(radius: 5) }
                    else if phase.error != nil { VStack { Image(systemName: "xmark.octagon.fill").foregroundColor(.red); Text("Load Failed") } .frame(height: 300) }
                    else { ProgressView().frame(height: 300) }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Status: \(image.status.capitalized)").font(.title2).fontWeight(.semibold)
                    if let prompt = image.prompt, !prompt.isEmpty {
                        Text("Prompt:").font(.headline); Text(prompt).font(.body).foregroundColor(.secondary)
                    }
                    Text("Uploaded:").font(.headline)
                    Text("\(image.createdAt, style: .date), \(image.createdAt, style: .time)").font(.body).foregroundColor(.secondary)
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Image Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ImageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
             ImageDetailView(image: ImageData.previewData[0]) // Uses preview data with Int ID
        }
    }
}
