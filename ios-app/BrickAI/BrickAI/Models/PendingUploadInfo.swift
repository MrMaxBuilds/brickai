// MARK: NEW FILE - Models/PendingUploadInfo.swift
// File: BrickAI/Models/PendingUploadInfo.swift
// Represents an image upload that is pending confirmation from the backend.

import Foundation
import SwiftUI // For Identifiable, UIImage

//<-----CHANGE START------>
// Made properties non-optional for simpler dummy row display initially
// Added placeholder for thumbnail data
struct PendingUploadInfo: Identifiable {
    let id: UUID // Use the client-generated UUID for identity
    let placeholderImageName: String = "hourglass.circle" // System icon for pending
    let createdAt: Date // Time the pending upload was initiated

    // Simple initializer
    init(id: UUID = UUID(), createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
    }
}
//<-----CHANGE END-------->
// MARK: END NEW FILE - Models/PendingUploadInfo.swift