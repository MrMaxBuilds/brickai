// File: BrickAI/Views/ImageListView.swift
// Rewritten with improved formatting and error handling alert

import SwiftUI

@MainActor // Ensure UI updates happen on the main thread
class ImageListViewModel: ObservableObject {
    @Published var images: [ImageData] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Computed property to easily bind alert presentation
    var shouldShowErrorAlert: Binding<Bool> {
        Binding<Bool>(
            get: { self.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    self.errorMessage = nil // Clear error when alert is dismissed
                }
            }
        )
    }

    func fetchUserImages() {
        guard !isLoading else { return } // Prevent multiple simultaneous fetches

        print("ImageListViewModel: Starting image fetch...")
        isLoading = true
        errorMessage = nil // Clear previous errors on new fetch
        // Don't clear images immediately, only on success, for better refresh UX
        // images = []

        NetworkManager.fetchImages { [weak self] result in
            // Ensure we are still on the main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false // Stop loading indicator

                switch result {
                case .success(let fetchedImages):
                    print("ImageListViewModel: Successfully fetched \(fetchedImages.count) images.")
                    self.images = fetchedImages // Update images on success
                    self.errorMessage = nil // Clear any previous error on success

                case .failure(let error):
                    print("ImageListViewModel: Error fetching images: \(error.localizedDescription)")
                    // Handle specific errors if needed (like session expired)
                    if case .sessionExpired = error {
                         self.errorMessage = "Session expired. Please log out and log back in."
                         // Optionally trigger logout automatically
                         // UserManager.shared.clearUser()
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    // Keep stale images (if any) visible when showing error
                }
            }
        }
    }
}

struct ImageListView: View {
    @StateObject private var viewModel = ImageListViewModel()
    // Access user manager to allow manual logout if session expires
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        // Using NavigationStack is more modern, but NavigationView is fine here
        NavigationView {
            Group { // Group allows easy switching of main content view
                if viewModel.isLoading && viewModel.images.isEmpty {
                    // Show loading only if images are currently empty
                    ProgressView("Loading Images...")
                } else if viewModel.images.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
                    // Specific empty state view
                    Text("You haven't uploaded any images yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
                } else {
                    // Display the list (potentially with stale data if error occurred)
                    List {
                        ForEach(viewModel.images) { image in
                            NavigationLink(destination: ImageDetailView(image: image)) {
                                ImageRow(image: image)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { // Pull-to-refresh
                         await viewModel.fetchUserImages()
                     }
                     // Show loading indicator overlaid during refresh if needed
                     .overlay {
                          if viewModel.isLoading && !viewModel.images.isEmpty {
                               // Small progress indicator during refresh maybe? Or rely on refreshable spinner.
                               // ProgressView().scaleEffect(0.8)
                          }
                     }
                }
            }
            .navigationTitle("My Images")
            .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button {
                          viewModel.fetchUserImages()
                     } label: {
                          Image(systemName: "arrow.clockwise")
                     }
                     .disabled(viewModel.isLoading)
                 }
            }
            // --- Error Handling Alert ---
            .alert("Error Loading Images", isPresented: viewModel.shouldShowErrorAlert, presenting: viewModel.errorMessage) { _ in // Presenting message allows it in button closure
                Button("Retry") {
                    viewModel.fetchUserImages()
                }
                // If session expired, offer logout
                if viewModel.errorMessage == "Session expired. Please log out and log back in." {
                    Button("Log Out", role: .destructive) {
                        userManager.clearUser()
                        // View should react automatically via EnvironmentObject change
                    }
                } else {
                     Button("OK", role: .cancel) { } // Standard dismiss
                }
            } message: { message in
                Text(message) // Display the error message from the view model
            }
            // --- End Error Handling Alert ---
        }
        .onAppear {
            // Fetch images only if the list is currently empty when view appears
            if viewModel.images.isEmpty {
                 viewModel.fetchUserImages()
            }
        }
        // Use stack style on iPad if desired
        // .navigationViewStyle(.stack)
    }
}

// Row view for the list
struct ImageRow: View {
    let image: ImageData

    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: image.processedImageUrl ?? image.originalImageUrl) { phase in
                switch phase {
                case .empty:
                    ZStack { // Add background during loading
                        Color(.systemGray5)
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)

                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)

                case .failure:
                    ZStack { // Add background on failure
                        Color(.systemGray5)
                        Image(systemName: "photo.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(8) // Add padding to the SF Symbol
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)

                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60) // Keep consistent frame

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
                Text(image.createdAt, style: .relative) // Removed "Uploaded:", just show relative time
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer() // Push content to left
        }
        .padding(.vertical, 8) // Increased vertical padding for better spacing
    }

    // Helper to determine status color (no changes needed)
    private func statusColor(status: String) -> Color {
        switch status.uppercased() {
        case "UPLOADED", "PROCESSING": return .orange
        case "COMPLETED": return .green
        case "FAILED": return .red
        default: return .primary
        }
    }
}

