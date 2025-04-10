// MARK: NEW FILE - Models/PendingUploadInfo.swift
// File: BrickAI/Models/PendingUploadInfo.swift
// Represents an image upload that is pending confirmation from the backend.

import Foundation
import SwiftUI // For Identifiable

struct PendingUploadInfo: Identifiable {
    let id: UUID // Use the client-generated UUID for identity
    let localThumbnailData: Data? // Store Data (e.g., PNG/JPEG) for the thumbnail
    let createdAt: Date // Time the pending upload was initiated

    // Initializer
    init(id: UUID = UUID(), localThumbnailData: Data?, createdAt: Date = Date()) {
        self.id = id
        self.localThumbnailData = localThumbnailData
        self.createdAt = createdAt
    }
}
// MARK: END NEW FILE - Models/PendingUploadInfo.swift