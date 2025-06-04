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

    // New struct for product display details
    struct ProductDisplayDetails {
        let tries: Int
        let imageName: String // Still here, but not used in the view
        let isPopular: Bool // To mark the "Most Popular" option
    }

    // Map product IDs to their display details
    private let productDetailsMap: [String: ProductDisplayDetails] = [
        "com.NEXTAppDevelopment.brickai.1dollar": ProductDisplayDetails(tries: 5, imageName: "brickai_1_dollar", isPopular: false),
        "com.NEXTAppDevelopment.brickai.5dollars": ProductDisplayDetails(tries: 30, imageName: "brickai_5_dollars", isPopular: true),
        "com.NEXTAppDevelopment.brickai.20dollars": ProductDisplayDetails(tries: 100, imageName: "brickai_20_dollars", isPopular: false)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Sale")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 30)
                .foregroundColor(.black) // Title should be black

            if storeManager.isLoadingProducts {
                ProgressView("Loading Products...")
                    .padding()
            } else {
                // Iterate over sorted products that are in our productDetailsMap
                let displayableProducts = storeManager.products.filter { productDetailsMap.keys.contains($0.productIdentifier) }

                if !displayableProducts.isEmpty {
// <-----CHANGE START------>
                    // Use a ScrollView to ensure content is scrollable if it exceeds screen height
                    ScrollView {
                        VStack(spacing: 15) { // Reduced spacing between cards
                            ForEach(displayableProducts.sorted(by: { (p1, p2) -> Bool in
                                // Custom sorting: popular first, then by price
                                guard let details1 = productDetailsMap[p1.productIdentifier],
                                      let details2 = productDetailsMap[p2.productIdentifier] else {
                                    return false // Should not happen if products are filtered
                                }
                                if details1.isPopular && !details2.isPopular {
                                    return true
                                } else if !details1.isPopular && details2.isPopular {
                                    return false
                                }
                                return p1.price.decimalValue < p2.price.decimalValue
                            }), id: \.productIdentifier) { product in
                                productPurchaseView(product: product)
                            }
                        }
                        .padding(.horizontal) // Horizontal padding for the VStack of cards
                        .padding(.top, 20) // Padding above the first card
                        .padding(.bottom, 20) // Padding below the last card
                    }
// <-----CHANGE END-------->
                } else {
                    // No products found or not loaded yet
                    Text("No products available at the moment. Please try again later.")
                        .foregroundColor(.gray) // Adjusted for white background
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Refresh Products") {
                        storeManager.fetchProducts()
                    }
                    .padding()
                    .tint(.blue) // Explicitly set tint if needed
                }
            }

            Spacer() // Pushes content to the top

            // Display transaction status (optional, for debugging or more detailed UI)
            if let state = storeManager.transactionState {
                Text("Transaction Status: \(transactionStatusString(state))")
                    .font(.caption)
                    .foregroundColor(.gray) // Adjusted for white background
                    .padding(.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea()) // White background for the whole view
        .navigationTitle("Purchase Credits") // This title will be used if embedded in NavigationView
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
// <-----CHANGE START------>
        // Ensure productDetails exist for the given product
        if let details = productDetailsMap[product.productIdentifier] {
            ZStack(alignment: .topLeading) { // Use ZStack for the "Most Popular" badge overlay
                // Main card content
                VStack(spacing: 0) { // Set spacing to 0, control with padding
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { // Reduced spacing
                            Text("\(details.tries)")
                                .font(.system(size: 36, weight: .bold)) // Larger credit count
                                .foregroundColor(.black)
                            Text("Credits")
                                .font(.footnote) // Smaller "Credits" text
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(product.localizedPrice ?? "Price")
                            .font(.title2) // Slightly larger price
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20) // Padding for top content
                    .padding(.bottom, 15) // Spacing below text content

                    Button(action: {
                        // Initiate purchase
                        storeManager.buyProduct(product) { result in
                            handlePurchaseCompletion(result: result, product: product)
                        }
                    }) {
                        // Dynamic button label based on purchase state
                        if storeManager.transactionState == .purchasing &&
                           storeManager.products.first(where: { $0.productIdentifier == product.productIdentifier }) != nil &&
                           SKPaymentQueue.default().transactions.first(where: {$0.payment.productIdentifier == product.productIdentifier && $0.transactionState == .purchasing }) != nil {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44) // Fixed height for the button area
                        } else {
                            Text("Buy Now")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44) // Fixed height for the button
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(8) // Slightly less rounded corners for button
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20) // Padding for button at bottom
                    .disabled(storeManager.transactionState == .purchasing)
                }
                .background(Color(UIColor.systemGray6)) // Use a very light gray for card background
                .cornerRadius(12) // Card corner radius
                // .shadow(color: .gray.opacity(0.25), radius: 5, x: 0, y: 3) // Subtle shadow

                // "Most Popular" Badge
                if details.isPopular {
                    Text("Most Popular")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange) // Changed badge color
                        .clipShape(Capsule())
                        .offset(x: -8, y: -12) // Position badge at top-left, slightly offset
                }
            }
            .padding(.bottom, 5) // Small space below each card before the next one
        } else {
            // Fallback if productDetails are somehow not found (should be rare)
            Text("Product information for \(product.productIdentifier) is not available.")
                .padding()
                .foregroundColor(.red)
        }
// <-----CHANGE END-------->
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

            case .failure(let error):
                // Purchase failed
                print("PaymentsView: Purchase failed for \(product.localizedTitle). Error: \(error.localizedDescription)")
                if let skError = error as? SKError, skError.code == .paymentCancelled {
                    // User cancelled, no alert needed or a subtle one
                    self.alertTitle = "Purchase Cancelled"
                    self.alertMessage = "Your purchase of \(product.localizedTitle) was cancelled."
                    // Optionally show alert: self.showAlert = true
                } else {
                    self.alertTitle = "Purchase Failed"
                    self.alertMessage = "Could not complete your purchase of \(product.localizedTitle). \(error.localizedDescription)"
                    self.showAlert = true
                }
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
