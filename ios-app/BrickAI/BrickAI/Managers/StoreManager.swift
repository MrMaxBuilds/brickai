// MARK: NEW FILE - Managers/StoreManager.swift
// File: BrickAI/Managers/StoreManager.swift
// Manages In-App Purchases using StoreKit.

import Foundation
import StoreKit

// Define a typealias for the completion handler for purchases
typealias PurchaseCompletionHandler = (Result<SKPaymentTransaction, Error>) -> Void

// Define possible errors for the StoreManager
enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseNotAllowed
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The purchase could not be verified."
        case .productNotFound:
            return "The requested product could not be found."
        case .purchaseNotAllowed:
            return "This device is not allowed to make purchases."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

@MainActor
class StoreManager: NSObject, ObservableObject {

    // MARK: - Published Properties
    // Holds the products fetched from the App Store
    @Published var products: [SKProduct] = []
    // Tracks the current purchase state (e.g., purchasing, purchased, failed)
    @Published var transactionState: SKPaymentTransactionState?
    // Tracks if products are currently being loaded
    @Published var isLoadingProducts: Bool = false

    // MARK: - Private Properties
    // Set of product identifiers to fetch. This MUST match what's in App Store Connect.
    // For this task, we'll use a placeholder. Replace with your actual Product ID.
// <-----CHANGE START------>
    private let productIdentifiers: Set<String> = [
        "com.NEXTAppDevelopment.brickai.1dollar",
        "com.NEXTAppDevelopment.brickai.5dollars",
        "com.NEXTAppDevelopment.brickai.20dollars"
    ]
// <-----CHANGE END-------->
    
    // Completion handler for the current purchase attempt
    private var onPurchaseCompleted: PurchaseCompletionHandler?

    // MARK: - Initialization
    override init() {
        super.init()
        print("StoreManager: Initializing and preparing to add to payment queue.")
        // Add this class as an observer of the payment queue
        SKPaymentQueue.default().add(self)
        print("StoreManager: Initialized. Self has been added as an observer to SKPaymentQueue.default().")
    }

    deinit {
        // Remove this class as an observer when it's deallocated
        SKPaymentQueue.default().remove(self)
        print("StoreManager: Deinitialized and removed from payment queue.")
    }

    // MARK: - Public Methods

    /// Fetches product information from the App Store.
    func fetchProducts() {
        guard !isLoadingProducts else {
            print("StoreManager: Product fetch already in progress.")
            return
        }
        
        print("StoreManager: Starting to fetch products for identifiers: \(productIdentifiers)")
        isLoadingProducts = true
        transactionState = nil // Reset transaction state

        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        print("StoreManager: SKProductsRequest created with identifiers: \(productIdentifiers). Starting request...")
        request.start() // This will trigger delegate methods
    }

    /// Initiates a purchase for the given product.
    /// - Parameters:
    ///   - product: The `SKProduct` to purchase.
    ///   - completion: A closure that will be called when the purchase attempt is complete.
    func buyProduct(_ product: SKProduct, completion: @escaping PurchaseCompletionHandler) {
        guard SKPaymentQueue.canMakePayments() else {
            print("StoreManager: Purchases are not allowed on this device.")
            completion(.failure(StoreError.purchaseNotAllowed))
            return
        }

        print("StoreManager: Initiating purchase for product: \(product.productIdentifier)")
        onPurchaseCompleted = completion // Store the completion handler
        transactionState = .purchasing // Update UI state

        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment) // Add payment to the queue
    }
}

// MARK: - SKProductsRequestDelegate
extension StoreManager: SKProductsRequestDelegate {
    /// Called when the product request successfully finishes.
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // Update products on the main thread
        DispatchQueue.main.async {
            self.isLoadingProducts = false
// <-----CHANGE START------>
            // Sort products by price to ensure a consistent order if needed
            self.products = response.products.sorted { $0.price.decimalValue < $1.price.decimalValue }
// <-----CHANGE END-------->
            if response.products.isEmpty {
                print("StoreManager: No products found for the given identifiers.")
            } else {
                print("StoreManager: Successfully fetched \(response.products.count) products.")
                response.products.forEach { product in
                    print("StoreManager: - Product ID: \(product.productIdentifier), Price: \(product.localizedPrice ?? "N/A")")
                }
            }
            
            // Log any invalid product identifiers
            if !response.invalidProductIdentifiers.isEmpty {
                print("StoreManager: Invalid product identifiers: \(response.invalidProductIdentifiers)")
            }
        }
    }

    /// Called when the product request fails.
    func request(_ request: SKRequest, didFailWithError error: Error) {
        // Update state on the main thread
        DispatchQueue.main.async {
            self.isLoadingProducts = false
            print("StoreManager: Failed to fetch products: \(error.localizedDescription)")
            // Optionally, you could set an error state here to display to the user
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension StoreManager: SKPaymentTransactionObserver {
    /// Called when the transaction status updates.
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            // Update the published transaction state on the main thread
            DispatchQueue.main.async {
                self.transactionState = transaction.transactionState
            }

            switch transaction.transactionState {
            case .purchasing:
                print("StoreManager: Transaction Purchasing - Product: \(transaction.payment.productIdentifier)")
                // UI is already updated via @Published transactionState
                break
            case .purchased:
                print("StoreManager: Transaction Purchased - Product: \(transaction.payment.productIdentifier)")
                handlePurchased(transaction)
                queue.finishTransaction(transaction) // Important: Finish the transaction
            case .failed:
                print("StoreManager: Transaction Failed - Product: \(transaction.payment.productIdentifier), Error: \(transaction.error?.localizedDescription ?? "No error info")")
                handleFailed(transaction)
                queue.finishTransaction(transaction) // Important: Finish the transaction
            case .restored:
                print("StoreManager: Transaction Restored - Product: \(transaction.payment.productIdentifier)")
                // Handle restored purchases (e.g., for non-consumables or subscriptions)
                // For consumables, this might not grant the item again but good to acknowledge.
                // For simplicity in this initial version for a consumable, we'll just finish it.
                queue.finishTransaction(transaction)
            case .deferred:
                print("StoreManager: Transaction Deferred - Product: \(transaction.payment.productIdentifier)")
                // The transaction is in the queue, but its final status is pending external action (e.g., Ask to Buy)
                // UI should inform the user that the purchase is waiting for approval.
                onPurchaseCompleted?(.failure(transaction.error ?? StoreError.unknown)) // Notify of deferred state
                // Do not finish the transaction yet.
            @unknown default:
                print("StoreManager: Unknown transaction state.")
                queue.finishTransaction(transaction) // Finish unknown states to prevent queue blockage
                onPurchaseCompleted?(.failure(StoreError.unknown))
            }
        }
    }

    /// Optional: Called when transactions are removed from the queue (e.g., after `finishTransaction`).
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        print("StoreManager: \(transactions.count) transaction(s) removed from the queue.")
        transactions.forEach { transaction in
            print("StoreManager: - Removed transaction for product: \(transaction.payment.productIdentifier)")
        }
    }

    /// Optional: Called when an error occurs while restoring purchases.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("StoreManager: Restore completed transactions failed with error: \(error.localizedDescription)")
        // Update UI to inform the user about the failure
    }

    /// Optional: Called when all restorable purchases have been processed.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("StoreManager: Payment queue restore completed transactions finished.")
        // Update UI if needed
        if queue.transactions.isEmpty {
            print("StoreManager: No transactions were restored.")
        }
    }
    
    // MARK: - Private Helper Methods

    /// Handles a successfully purchased transaction.
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        print("StoreManager: Handling purchased transaction for \(transaction.payment.productIdentifier)")
        
        // --- IMPORTANT: Grant Content/Update User State VIA BACKEND ---
        let productId = transaction.payment.productIdentifier
        print("StoreManager: Calling NetworkManager to add credits for product ID: \(productId)")

        NetworkManager.addCreditsForPurchase(productId: productId) { result in
            // This completion handler is called on the main thread by NetworkManager
            switch result {
            case .success(let newTotalCredits):
                print("StoreManager: Successfully updated credits via backend. New total: \(newTotalCredits).")
                // Here you could update a local user model or trigger UI updates based on the new credit total
                // For example: UserManager.shared.updateLocalCredits(newTotalCredits)
                // Notify the purchase completion handler AFTER successful backend update
                self.onPurchaseCompleted?(.success(transaction))
            case .failure(let error):
                print("StoreManager: Failed to update credits via backend for product ID \(productId). Error: \(error.localizedDescription)")
                // Handle the error appropriately. 
                // For now, we still call the purchase completion with success for the transaction itself,
                // as the App Store purchase was successful. The backend sync failed.
                // You might want a more sophisticated error handling strategy here, e.g., 
                // retry mechanism, or informing the user that the purchase was made but credits update failed.
                // Depending on the error type, you might also consider not fulfilling the purchase locally
                // if backend sync is critical.
                // For now, let's assume the purchase is valid and we'll complete it, but log the backend error.
                self.onPurchaseCompleted?(.success(transaction)) // Or .failure(error) if you want to signify the overall operation failed
            }
            self.onPurchaseCompleted = nil // Reset for next purchase (moved here to ensure it's called in both success/failure paths)
        }
        // --- OLD Grant Content/Update User State (Conceptual) ---
        // This is where you would:
        // 1. Verify the receipt (ideally server-side, but can be client-side for simplicity initially).
        // 2. If verified, unlock the content or update the user's "tries".
        // For example, if productIdentifier == "com.yourapp.30tries", add 30 to user's tries.
        //
        // Example (conceptual - actual update mechanism depends on your UserManager/data model):
        // if transaction.payment.productIdentifier == "com.yourapp.30tries" {
        //     UserManager.shared.addTries(30) // You'll need to implement this
        //     print("StoreManager: 30 tries granted to the user.")
        // }
        // ---
    }

    /// Handles a failed transaction.
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        print("StoreManager: Handling failed transaction for \(transaction.payment.productIdentifier)")
        var errorToReport: Error = StoreError.unknown
        if let error = transaction.error as? SKError {
            // More specific SKError handling
            if error.code == .paymentCancelled {
                print("StoreManager: Payment cancelled by user.")
                // No need to show a generic error if user cancelled.
                // The UI should ideally just return to its previous state.
                // For the completion handler, we still signal a failure but can be specific.
                errorToReport = error // Pass the SKError itself
            } else {
                print("StoreManager: SKError code: \(error.code.rawValue) - \(error.localizedDescription)")
                errorToReport = error // Pass the SKError
            }
        } else if let error = transaction.error {
            print("StoreManager: Generic transaction error: \(error.localizedDescription)")
            errorToReport = error // Pass the generic Error
        }
        
        onPurchaseCompleted?(.failure(errorToReport))
        onPurchaseCompleted = nil // Reset for next purchase
    }
}

// Helper to format price
extension SKProduct {
    var localizedPrice: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        return formatter.string(from: price)
    }
}