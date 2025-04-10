// MARK: NEW FILE - Views/ImageList/PendingImageRow.swift
// File: BrickAI/Views/ImageList/PendingImageRow.swift
// Displays a row for an image upload pending confirmation.

import SwiftUI

struct PendingImageRow: View {
    let pendingUpload: PendingUploadInfo

    var body: some View {
        HStack(spacing: 15) {
            // Placeholder Image
            Image(systemName: pendingUpload.placeholderImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40) // Slightly smaller perhaps
                .foregroundColor(.secondary)
                .padding(10) // Padding within the frame
                .frame(width: 60, height: 60) // Match frame size
                .background(Color(.systemGray6))
                .cornerRadius(8)

            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Status: Uploading...") // Or "Pending..."
                    .font(.headline)
                    .foregroundColor(.orange) // Use orange for pending status
                Text(pendingUpload.createdAt, style: .relative) // Show when it was added to queue
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            ProgressView() // Show spinner for pending items
                .scaleEffect(0.8) // Make spinner smaller
                .padding(.trailing, 5)

        }
        .padding(.vertical, 8)
        // Add subtle visual difference, like reduced opacity
        .opacity(0.7)
    }
}

// Preview for PendingImageRow
struct PendingImageRow_Previews: PreviewProvider {
    static var previews: some View {
        PendingImageRow(pendingUpload: PendingUploadInfo())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
// MARK: END NEW FILE - Views/ImageList/PendingImageRow.swift