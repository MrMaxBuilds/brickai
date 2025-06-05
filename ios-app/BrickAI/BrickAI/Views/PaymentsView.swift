// MARK: MODIFIED FILE - Views/PaymentsView.swift
// File: BrickAI/Views/PaymentsView.swift
// Updated to integrate with StoreManager for In-App Purchases.
// Moved "Most Popular" indicator to be a blue bar overlaying the $1 item.
// <-----CHANGE START------>
// Refactored productPurchaseView to break up complex expressions.
// <-----CHANGE END-------->

import SwiftUI
import StoreKit // Import StoreKit

// Helper Shape for rounding specific corners
struct CustomRoundedCorners: Shape {
    var tl: CGFloat = 0.0
    var tr: CGFloat = 0.0
    var bl: CGFloat = 0.0
    var br: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.size.width
        let h = rect.size.height

        // Make sure radius does not exceed half the shorter side
        let Mtr = min(min(self.tr, h/2), w/2)
        let Mtl = min(min(self.tl, h/2), w/2)
        let Mbl = min(min(self.bl, h/2), w/2)
        let Mbr = min(min(self.br, h/2), w/2)

        path.move(to: CGPoint(x: w / 2.0, y: 0))
        path.addLine(to: CGPoint(x: w - Mtr, y: 0))
        path.addArc(center: CGPoint(x: w - Mtr, y: Mtr), radius: Mtr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)

        path.addLine(to: CGPoint(x: w, y: h - Mbr))
        path.addArc(center: CGPoint(x: w - Mbr, y: h - Mbr), radius: Mbr, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)

        path.addLine(to: CGPoint(x: Mbl, y: h))
        path.addArc(center: CGPoint(x: Mbl, y: h - Mbl), radius: Mbl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)

        path.addLine(to: CGPoint(x: 0, y: Mtl))
        path.addArc(center: CGPoint(x: Mtl, y: Mtl), radius: Mtl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

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
    // Updated isPopular flags: $1 is now popular, $5 is not (for this specific indicator)
    private let productDetailsMap: [String: ProductDisplayDetails] = [
        "com.NEXTAppDevelopment.brickai.1dollar": ProductDisplayDetails(tries: 5, imageName: "brickai_1_dollar", isPopular: true),
        "com.NEXTAppDevelopment.brickai.5dollars": ProductDisplayDetails(tries: 30, imageName: "brickai_5_dollars", isPopular: false),
        "com.NEXTAppDevelopment.brickai.20dollars": ProductDisplayDetails(tries: 150, imageName: "brickai_20_dollars", isPopular: false)
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
                    // Use a ScrollView to ensure content is scrollable if it exceeds screen height
                    ScrollView {
                        VStack(spacing: 15) { // Reduced spacing between cards
                            // Products are now displayed sorted by price (least to most expensive)
                            // as displayableProducts preserves the order from storeManager.products.
                            ForEach(displayableProducts, id: \.productIdentifier) { product in
                                productPurchaseView(product: product)
                            }
                            // Add a Spacer to push content to the top if it doesn't fill the ScrollView height
                            if !displayableProducts.isEmpty {
                                Spacer()
                            }
                        }
                        .padding(.horizontal) // Horizontal padding for the VStack of cards
                        .padding(.top, 20) // Padding above the first card
                        .padding(.bottom, 20) // Padding below the last card
                    }
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

// <-----CHANGE START------>
    /// Creates the main visual content of a product card.
    @ViewBuilder
    private func productCardMainContent(product: SKProduct, details: ProductDisplayDetails) -> some View {
        VStack(spacing: 0) {
            let barHeight: CGFloat = 30 // Approximate height of the popular bar
            // If this item is popular, its content needs to start below the bar.
            let contentTopPadding = details.isPopular ? barHeight + 10 : 20

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(details.tries)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    Text("Credits")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(product.localizedPrice ?? "Price")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.top, contentTopPadding) // Use calculated top padding
            .padding(.bottom, 15)

            Button(action: {
                storeManager.buyProduct(product) { result in
                    handlePurchaseCompletion(result: result, product: product)
                }
            }) {
                // Dynamic button label based on purchase state
                if storeManager.transactionState == .purchasing &&
                   SKPaymentQueue.default().transactions.first(where: {$0.payment.productIdentifier == product.productIdentifier && $0.transactionState == .purchasing }) != nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    Text("Buy Now")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .disabled(storeManager.transactionState == .purchasing)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    /// Creates the "Most Popular" bar view.
    @ViewBuilder
    private func popularProductBar() -> some View {
        Text("Most Popular")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.yellow.opacity(0.9))
            .clipShape(CustomRoundedCorners(tl: 12, tr: 12, bl: 0, br: 0))
    }

    /// Creates a view for a single product, allowing purchase.
    @ViewBuilder
    private func productPurchaseView(product: SKProduct) -> some View {
        // Ensure productDetails exist for the given product
        if let details = productDetailsMap[product.productIdentifier] {
            ZStack(alignment: .top) {
                // Main card content (drawn first, so it's underneath the bar)
                productCardMainContent(product: product, details: details)

                // "Most Popular" Bar - Replaces the old badge
                if details.isPopular { // This will be true for the $1 item
                    popularProductBar()
                }
            }
            .padding(.bottom, 5) // Small space below each card before the next one
        } else {
            // Fallback if productDetails are somehow not found (should be rare)
            Text("Product information for \(product.productIdentifier) is not available.")
                .padding()
                .foregroundColor(.red)
        }
    }
// <-----CHANGE END-------->

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
