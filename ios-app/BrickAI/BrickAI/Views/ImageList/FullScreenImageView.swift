//
//  FullScreenImageView.swift
//  BrickAI
//
//  Created by Max U on 4/8/25.
//


// FullScreenImageView.swift
import SwiftUI

struct FullScreenImageView: View {
    // The image to display. Pass this in when you create the view.
    let image: Image

    // Environment variable to allow dismissing this presented view
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Background color (often black for image viewers)
            Color.black
                .edgesIgnoringSafeArea(.all) // Extend background to screen edges

            // The image itself
            image
                .resizable()
                .scaledToFit() // Scale to fit while maintaining aspect ratio
                .edgesIgnoringSafeArea(.all) 

             VStack {
                 HStack {
                     Spacer() // Push button to the right
                     Button {
                         dismiss() // Dismiss the view
                     } label: {
                         Image(systemName: "xmark.circle.fill")
                             .font(.largeTitle)
                             .foregroundColor(.white)
                             .padding()
                             .background(Color.black.opacity(0.5)) // Semi-transparent background for visibility
                             .clipShape(Circle())
                     }
                     .padding([.top, .trailing]) // Add some padding from the edge
                 }
                 Spacer() // Push button to the top
             }

        }
        // Make the entire ZStack tappable to dismiss the view
        .onTapGesture {
            dismiss()
        }
    }
}

// MARK: - Preview
// You can customize the preview with a sample image
struct FullScreenImageView_Previews: PreviewProvider {
    static var previews: some View {
        // Replace "placeholder" with a valid image name in your assets
        // or use Image(systemName: "photo")
        FullScreenImageView(image: Image(systemName: "photo.artframe")) 
    }
}
