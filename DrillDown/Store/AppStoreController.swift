//
//  AppStoreController.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 2/12/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa
import StoreKit

protocol AppStoreControllerDelegate: AnyObject {
	/// Tells the delegate that the buy operation was successful.
	func appStoreControllerPurchaseDidSucceed()

	/// Tells the delegate that the restore operation was successful.
	func appStoreControllerRestoreDidSucceed()
	
	/// The user canceled a purchase without an error.
	func appStoreControllerDidCancelPurchase()
	
	/// Tells the delegate that the receipt refresh was successful.
	func appStoreControllerReceiptRefreshDidSucceed()

	/// Provides the delegate with messages.
	func appStoreControllerDidReceiveMessage(_ message: String)
}

protocol AppStoreControllerAvailableProductsDelegate: AnyObject {
	/// The availableProducts have been loaded from the app store
	func appStoreControllerDidLoadAvailableProducts()
}

class AppStoreController: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate, SKRequestDelegate {
	
	
	func connectToStore() {
		if let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) {
			if isAuthorizedForPayments {
				SKPaymentQueue.default().add(self)
				hasRegisteredForNotifications = true
			}
		}
		else {
			receiptRequest = SKReceiptRefreshRequest()
			receiptRequest?.delegate = self
			receiptRequest?.start()
		}
	}
	
	func disconnectFromStore() {
		if hasRegisteredForNotifications ?? false {
			SKPaymentQueue.default().remove(self)
		}
	}
	
	func fetchAvailableProducts(matchingIdentifiers productIdentifiers: [String]) {
		// Initialize the product request with the above identifiers.
		productRequest = SKProductsRequest(productIdentifiers: Set(productIdentifiers))
		productRequest?.delegate = self

		// Send the request to the App Store.
		productRequest?.start()
	}
	
	/// Keeps track of all valid products. These products are available for sale in the App Store.
	var availableProducts = [SKProduct]()
	
	/// Create and add a payment request to the payment queue.
	func buy(_ product: SKProduct) {
		let payment = SKMutablePayment(product: product)
		SKPaymentQueue.default().add(payment)
	}
	
	func restorePastPurchases() {
		if restored.isEmpty == false {
			restored.removeAll()
		}
		SKPaymentQueue.default().restoreCompletedTransactions()
	}
	
	// MARK: - Private
		
	/// Keeps track of all purchases.
	private var purchased = [SKPaymentTransaction]()

	/// Keeps track of all restored purchases.
	private var restored = [SKPaymentTransaction]()
	
	/// Indicates whether there are restorable purchases.
	private var hasRestorablePurchases = false
	
	private var productRequest: SKProductsRequest?
	
	private var receiptRequest: SKReceiptRefreshRequest?

	/// Indicates whether we have registered with the payment queue.
	fileprivate var hasRegisteredForNotifications: Bool?

	weak var delegate: AppStoreControllerDelegate?
	weak var availableProductsDelegate: AppStoreControllerAvailableProductsDelegate?
	
	private var isAuthorizedForPayments: Bool {
		return SKPaymentQueue.canMakePayments()
	}
	
	// MARK: - Handle Payment Transactions

	/// Handles successful purchase transactions.
	private func handlePurchased(_ transaction: SKPaymentTransaction) {
		purchased.append(transaction)
		print("Deliver content for \(transaction.payment.productIdentifier).")

		DispatchQueue.main.async {
			self.delegate?.appStoreControllerPurchaseDidSucceed()
		}
		
		// Finish the successful transaction.
		SKPaymentQueue.default().finishTransaction(transaction)
	}

	/// Handles failed purchase transactions.
	private func handleFailed(_ transaction: SKPaymentTransaction) {
		var message = "Purchase of \(transaction.payment.productIdentifier) failed."

		if let error = transaction.error {
			message += "\nError: \(error.localizedDescription)"
			print("Error: \(error.localizedDescription)")
		}

		// Do not send any notifications when the user cancels the purchase.
		if (transaction.error as? SKError)?.code != .paymentCancelled {
			DispatchQueue.main.async {
				self.delegate?.appStoreControllerDidReceiveMessage(message)
			}
		}
		else {
			DispatchQueue.main.async {
				self.delegate?.appStoreControllerDidCancelPurchase()
			}
		}
		// Finish the failed transaction.
		SKPaymentQueue.default().finishTransaction(transaction)
	}

	/// Handles restored purchase transactions.
	private func handleRestored(_ transaction: SKPaymentTransaction) {
		hasRestorablePurchases = true
		restored.append(transaction)
		print("Restore content for \(transaction.payment.productIdentifier).")

		DispatchQueue.main.async {
			self.delegate?.appStoreControllerRestoreDidSucceed()
		}
		// Finishes the restored transaction.
		SKPaymentQueue.default().finishTransaction(transaction)
	}
	
	// MARK: - SKPaymentTransactionObserver
	
	/// Called when there are transactions in the payment queue.
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			switch transaction.transactionState {
			case .purchasing: break
			// Do not block your UI. Allow the user to continue using your app.
			case .deferred: print("Allow the user to continue using your app.")
			// The purchase was successful.
			case .purchased: handlePurchased(transaction)
			// The transaction failed.
			case .failed: handleFailed(transaction)
			// There are restored products.
			case .restored: handleRestored(transaction)
			@unknown default: fatalError("Unknown payment transaction case.")
			}
		}
	}

	/// Logs all transactions that have been removed from the payment queue.
	func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			print ("\(transaction.payment.productIdentifier) was removed from the payment queue.")
		}
	}

	/// Called when an error occur while restoring purchases. Notify the user about the error.
	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		if let error = error as? SKError, error.code != .paymentCancelled {
			DispatchQueue.main.async {
				self.delegate?.appStoreControllerDidReceiveMessage(error.localizedDescription)
			}
		}
	}

	/// Called when all restorable transactions have been processed by the payment queue.
	func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		print("All restorable transactions have been processed by the payment queue.")

		if !hasRestorablePurchases {
			DispatchQueue.main.async {
				self.delegate?.appStoreControllerDidReceiveMessage("There are no restorable purchases.\nOnly previously bought non-consumable products and auto-renewable subscriptions can be restored.")
			}
		}
	}

	// MARK: - SKProductsRequestDelegate
	
	/// Used to get the App Store's response to your request and notify your observer.
	/// - Tag: ProductRequest
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		// products contains products whose identifiers have been recognized by the App Store. As such, they can be purchased.
		if !response.products.isEmpty {
			availableProducts = response.products
		}

		// invalidProductIdentifiers contains all product identifiers not recognized by the App Store.
		if !response.invalidProductIdentifiers.isEmpty {
			print("Error: invalid product identifiers \(response.invalidProductIdentifiers)")
		}

		DispatchQueue.main.async {
			self.availableProductsDelegate?.appStoreControllerDidLoadAvailableProducts()
		}
	}
	
	// MARK: - SKRequestDelegate
	
	func requestDidFinish(_ request: SKRequest) {
		if request == receiptRequest {
			self.delegate?.appStoreControllerReceiptRefreshDidSucceed()
		}
	}
	
	/// Called when the product request failed.
	func request(_ request: SKRequest, didFailWithError error: Error) {
		DispatchQueue.main.async {
			self.delegate?.appStoreControllerDidReceiveMessage(error.localizedDescription)
		}
	}

}
