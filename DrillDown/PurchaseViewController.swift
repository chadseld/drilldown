//
//  PurchaseViewController.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 2/13/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa
import StoreKit

class PurchaseViewController: NSViewController, AppStoreControllerAvailableProductsDelegate {

	@IBOutlet weak var buyButton: NSButton!
	@IBOutlet weak var restoreButton: NSButton!
	@IBOutlet weak var cancelButton: NSButton!
	private var product: SKProduct?
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		NotificationCenter.default.addObserver(self, selector: #selector(fullFeaturesPurchasedChangedNotification(_:)), name: AppDelegate.fullFeaturesPurchasedChangedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(purchaseCanceledNotification(_:)), name: AppDelegate.purchaseCanceledNotification, object: nil)
    }
	
	override func viewDidAppear() {
		restoreButton.isEnabled = true
		cancelButton.isEnabled = true
		
		buyButton.isEnabled = false

		if let appDelegate = NSApp.delegate as? AppDelegate {
			let store = appDelegate.appStoreController
			store.availableProductsDelegate = self
			store.fetchAvailableProducts(matchingIdentifiers: [AppDelegate.ProductID.drill_down_full_iap_mac_01])
		}
	}
	
	func appStoreControllerDidLoadAvailableProducts() {
		updateBuyButton()
	}
    
	@IBAction func cancel(_ sender: Any) {
		self.view.window?.close()
	}
	
	@IBAction func buy(_ sender: Any) {
		if AppDelegate.fullFeaturesPurchased {
			self.view.window?.close()
		}
		else {
			if let appDelegate = NSApp.delegate as? AppDelegate, let product = product {
				cancelButton.isEnabled = false
				restoreButton.isEnabled = false
				buyButton.isEnabled = false
				appDelegate.appStoreController.buy(product)
			}
		}
	}
	
	@IBAction func restore(_ sender: Any) {
		if let appDelegate = NSApp.delegate as? AppDelegate {
			let store = appDelegate.appStoreController
			restoreButton.isEnabled = false
			store.restorePastPurchases()
		}
	}
	
	@objc func fullFeaturesPurchasedChangedNotification(_ notification: Notification) {
		if AppDelegate.fullFeaturesPurchased {
			self.view.window?.close()
		}
		else {
			cancelButton.isEnabled = true
			restoreButton.isEnabled = true
			updateBuyButton()
		}
	}
	
	@objc func purchaseCanceledNotification(_ notification: Notification) {
		cancelButton.isEnabled = true
		restoreButton.isEnabled = true
		updateBuyButton()
	}

	private func updateBuyButton() {
		if AppDelegate.fullFeaturesPurchased {
			buyButton.title = NSLocalizedString("Done", comment: "")
			buyButton.isEnabled = true
		}
		else {
			if let appDelegate = NSApp.delegate as? AppDelegate {
				let store = appDelegate.appStoreController
				product = store.availableProducts.filter { $0.productIdentifier == AppDelegate.ProductID.drill_down_full_iap_mac_01 }.first
				if let product = product {
					let formatter = NumberFormatter()
					formatter.formatterBehavior = .behavior10_4
					formatter.numberStyle = .currency
					formatter.locale = product.priceLocale
					if let priceString = formatter.string(from: product.price) {
						buyButton.title = String(format: NSLocalizedString("Buy for %@…", comment: "button title"), priceString)
						buyButton.isEnabled = true
					}
				}
				else {
					buyButton.title = NSLocalizedString("Buy…", comment: "button title")
					buyButton.isEnabled = false
				}
			}
		}
	}
}
