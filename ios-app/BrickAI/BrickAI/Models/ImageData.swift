//
//  ImageData.swift
//  BrickAI
//
//  Created by Max U on 4/6/25.
//


// File: BrickAI/Models/ImageData.swift
// Modified for SERIAL Int ID

import Foundation

struct ImageData: Codable, Identifiable {
    let id: Int // Changed from UUID to Int to match SERIAL PK
    let status: String
    let prompt: String?
    let createdAt: Date
    let originalImageUrl: URL?
    let processedImageUrl: URL?

    // Coding keys remain the same if backend sends snake_case
    enum CodingKeys: String, CodingKey {
        case id, status, prompt
        case createdAt = "created_at"
        case originalImageUrl = "original_image_url"
        case processedImageUrl = "processed_image_url"
    }
}

// Example for PreviewProvider (Updated ID type)
extension ImageData {
    static var previewData: [ImageData] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            // Use Int IDs for preview examples
            ImageData(id: 1, status: "COMPLETED", prompt: "A cat made of bricks", createdAt: Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/0000FF/808080?text=Original+1"), processedImageUrl: URL(string: "https://via.placeholder.com/150/FF0000/FFFFFF?text=Processed+1")),
            ImageData(id: 2, status: "UPLOADED", prompt: "A dog made of bricks", createdAt: formatter.date(from: "2025-04-05T10:30:00.123Z") ?? Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/00FF00/808080?text=Original+2"), processedImageUrl: nil),
            ImageData(id: 3, status: "FAILED", prompt: "A house made of bricks", createdAt: formatter.date(from: "2025-04-04T15:00:00Z") ?? Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/FFFF00/808080?text=Original+3"), processedImageUrl: nil)
        ]
    }
}
