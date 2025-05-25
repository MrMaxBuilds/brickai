// MARK: MODIFIED FILE - Views/PaymentsView.swift
// File: BrickAI/Views/PaymentsView.swift
// Updated to integrate with StoreManager for In-App Purchases.

import SwiftUI
import StoreKit // Import StoreKit

struct PaymentsView: View {
    // EnvironmentObject to access the shared StoreManager instance
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    // State for managing alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // The specific product ID we are interested in for this view
    private let targetProductID = "com.NEXTAppDevelopment.brickai.5dollars" // <<< MUST MATCH StoreManager AND App Store Connect

    var body: some View {
        VStack(spacing: 20) {
            Text("Unlock More Creations")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 30)

            if storeManager.isLoadingProducts {
                ProgressView("Loading Products...")
                    .padding()
            } else {
                // Find the specific product we want to display
                if let product = storeManager.products.first(where: { $0.productIdentifier == targetProductID }) {
                    productPurchaseView(product: product)
                } else {
                    // Product not found or not loaded yet
                    Text("No products available at the moment. Please try again later.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Refresh Products") {
                        storeManager.fetchProducts()
                    }
                    .padding()
                }
            }
            
            Spacer() // Pushes content to the top

            // Display transaction status (optional, for debugging or more detailed UI)
            if let state = storeManager.transactionState {
                Text("Transaction Status: \(transactionStatusString(state))")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Purchase Tries")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Fetch products when the view appears if they haven't been loaded yet
            if storeManager.products.isEmpty {
                storeManager.fetchProducts()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertTitle == "Purchase Successful" {
                        dismiss()
                    }
                }
            )
        }
    }

    /// Creates a view for a single product, allowing purchase.
    @ViewBuilder
    private func productPurchaseView(product: SKProduct) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "bolt.3.fill") // Icon representing "tries" or "power-ups"
                .font(.system(size: 60))
                .foregroundColor(.orange) // Accent color for the icon
                .padding(.bottom, 10)

            Text(product.localizedTitle) // e.g., "30 Extra Tries"
                .font(.title2)
                .fontWeight(.semibold)

            Text(product.localizedDescription) // Detailed description from App Store Connect
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Button to purchase the product
            Button(action: {
                // Initiate purchase
                storeManager.buyProduct(product) { result in
                    handlePurchaseCompletion(result: result, product: product)
                }
            }) {
                // Dynamic button label based on purchase state
                if storeManager.transactionState == .purchasing &&
                   storeManager.products.first(where: { $0.productIdentifier == product.productIdentifier }) != nil { // Check if this is the product being purchased
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, minHeight: 30) // Maintain button height
                } else {
                    Text("Buy for \(product.localizedPrice ?? "Price")")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.blue) // Standard purchase button color
            .cornerRadius(10)
            .shadow(radius: 3)
            .disabled(storeManager.transactionState == .purchasing) // Disable while a purchase is in progress
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .padding(.vertical, 20)
        .background(Color.white) // Card-like background
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.4), radius: 5, x: 0, y: 2)
        .padding(.horizontal) // Overall padding for the card
    }

    /// Handles the completion of a purchase attempt.
    private func handlePurchaseCompletion(result: Result<SKPaymentTransaction, Error>, product: SKProduct) {
        DispatchQueue.main.async {
            switch result {
            case .success(let transaction):
                // Purchase was successful
                print("PaymentsView: Purchase successful for \(product.localizedTitle)!")
                self.alertTitle = "Purchase Successful"
                self.alertMessage = "You've successfully purchased \(product.localizedTitle)."
                self.showAlert = true
            
                // --- IMPORTANT: Grant Content ---
                // The StoreManager's handlePurchased method is the primary place for this.
                // If you need to update UI specifically in PaymentsView or trigger navigation,
                // you can do it here. For example, you might want to update a local "tries" display
                // if it were managed directly in this view, or pop the view.
                //
                // Example: If UserManager.shared.addTries(30) was called in StoreManager,
                // the user's state is updated. You might want to reflect that here or navigate away.
                // For now, we just show an alert and dismiss on OK.

            case .failure(let error):
                // Purchase failed
                print("PaymentsView: Purchase failed for \(product.localizedTitle). Error: \(error.localizedDescription)")
                if let skError = error as? SKError, skError.code == .paymentCancelled {
                    // User cancelled, no alert needed or a subtle one
                    self.alertTitle = "Purchase Cancelled"
                    self.alertMessage = "Your purchase of \(product.localizedTitle) was cancelled."
                } else {
                    self.alertTitle = "Purchase Failed"
                    self.alertMessage = "Could not complete your purchase of \(product.localizedTitle). \(error.localizedDescription)"
                }
                self.showAlert = true
            }
        }
    }
    
    /// Helper to convert transaction state to a readable string
    private func transactionStatusString(_ state: SKPaymentTransactionState) -> String {
        switch state {
        case .purchasing: return "Purchasing..."
        case .purchased: return "Purchased"
        case .failed: return "Failed"
        case .restored: return "Restored"
        case .deferred: return "Deferred (Awaiting Approval)"
        @unknown default: return "Unknown"
        }
    }
}
