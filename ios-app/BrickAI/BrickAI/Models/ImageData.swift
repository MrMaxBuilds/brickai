// File: BrickAI/Models/ImageData.swift
// Modified CodingKeys to expect camelCase JSON from backend

import Foundation

struct ImageData: Codable, Identifiable {
    let id: Int // Matches SERIAL PK
    let status: String
    let prompt: String?
    let createdAt: Date
    let originalImageUrl: URL?
    let processedImageUrl: URL?

    // Coding keys to match JSON *sent by the backend*.
    // If backend sends camelCase (e.g., 'createdAt'), list case without explicit string value.
    // If backend sends snake_case (e.g., 'created_at'), map it like `case propertyName = "json_key"`.
    enum CodingKeys: String, CodingKey {
        case id // Assumes backend sends 'id'
        case status // Assumes backend sends 'status'
        case prompt // Assumes backend sends 'prompt'

        // Adjust these to match the keys ACTUALLY being sent by your /api/images backend:
        // Assuming backend sends camelCase as per its internal mapping object:
        case createdAt
        case originalImageUrl
        case processedImageUrl

        // If backend was sending snake_case (like the corrected version I sent before), you would use:
        // case createdAt = "created_at"
        // case originalImageUrl = "original_image_url"
        // case processedImageUrl = "processed_image_url"
    }
}

// Example for PreviewProvider (remains the same structure, uses Int ID)
extension ImageData {
    static var previewData: [ImageData] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            ImageData(id: 1, status: "COMPLETED", prompt: "A cat made of bricks", createdAt: Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/0000FF/808080?text=Original+1"), processedImageUrl: URL(string: "https://via.placeholder.com/150/FF0000/FFFFFF?text=Processed+1")),
            ImageData(id: 2, status: "UPLOADED", prompt: "A dog made of bricks", createdAt: formatter.date(from: "2025-04-05T10:30:00.123Z") ?? Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/00FF00/808080?text=Original+2"), processedImageUrl: nil),
            ImageData(id: 3, status: "FAILED", prompt: "A house made of bricks", createdAt: formatter.date(from: "2025-04-04T15:00:00Z") ?? Date(), originalImageUrl: URL(string: "https://via.placeholder.com/150/FFFF00/808080?text=Original+3"), processedImageUrl: nil)
        ]
    }
}
