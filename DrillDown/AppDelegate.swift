//
//  AppDelegate.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/16/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AppStoreControllerDelegate {

	public var appStoreController = AppStoreController()
	public static var fullFeaturesPurchased = true
	
	static let fullFeaturesPurchasedChangedNotification = NSNotification.Name(rawValue: "fullFeaturesPurchasedChanged")
	static let purchaseCanceledNotification = Notification.Name(rawValue: "purchaseCanceled")
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		refreshActivationPolicy()
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		appStoreController.delegate = self
		appStoreController.connectToStore()
		checkForPurchase()
		
		NotificationCenter.default.addObserver(self, selector: #selector(menuConfigurationsChangedNotification(_:)), name: PreferencesViewController.configurationChangedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusItemRemovedNotification(_:)), name: DrillMenuController.statusItemRemovedNotification, object: nil)
		
		reloadStatusItems()
		
		if ApplicationPreferences.activationPolicy == .regular {
			showPreferences(self)
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		appStoreController.disconnectFromStore()
		DrillMenuConfiguration.clearSecurityScopeAccessCache()
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		if flag == false {
			showPreferences(self)
		}
		return true
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		refreshActivationPolicy()
		refreshLaunchAtLogin()
		return false
	}
	
	@objc func menuConfigurationsChangedNotification(_ notification: Notification) {
		reloadStatusItems()
	}
	
	@objc func statusItemRemovedNotification(_ notification: Notification) {
		if let config = notification.object as? DrillMenuConfiguration {
			let configs = ApplicationPreferences.loadMenuConfigurations().filter { $0 != config }
			ApplicationPreferences.saveMenuConfigurations(configs)
			reloadStatusItems()
		}
	}
	
	func showFirstRunPopover() {
		let popover = NSPopover()
		popover.contentViewController = NSStoryboard.main?.instantiateController(withIdentifier: "firstRunStatusItemPopoverView") as? NSViewController
		popover.behavior = .transient
		menuControllers.values.first?.showPopover(popover)
	}
	
	@IBAction func menuItemSelected(_ sender: Any) {
		if let menuItem = sender as? NSMenuItem, let url = menuItem.representedObject as? URL {
			
			if isCommandKeyPressed() {
				NSWorkspace.shared.activateFileViewerSelecting([url])
			}
			else {
				NSWorkspace.shared.open(url)
			}
		}
		else {
			NSSound.beep()
		}
	}
	
	// MARK: - Private

	var preferencesWindowController: NSWindowController?
	var purchaseWindowController: NSWindowController?
	var menuControllers: [DrillMenuConfiguration : DrillMenuController] = [ : ]
	
	private func reloadStatusItems() {
		let configs = ApplicationPreferences.loadMenuConfigurations()

		configs.reversed().forEach { (config) in
			if menuControllers[config] == nil {
				menuControllers[config] = DrillMenuController(config: config)
			}
			if let controller = menuControllers[config] {
				controller.updateWithNewConfiguration(config)
			}
		}
		
		let toRemove = menuControllers.keys.filter { configs.contains($0) == false }
		toRemove.forEach { (config) in
			menuControllers[config]?.uninstallStatusItem()
		}
		
		readStatusItemOrder()
	}
	
	@IBAction func showPurchase(_ sender: Any) {
		if purchaseWindowController == nil {
			purchaseWindowController = NSStoryboard.main?.instantiateController(withIdentifier: "purchaseWindow") as? NSWindowController
		}
		NSApp.setActivationPolicy(.regular)
		purchaseWindowController?.showWindow(sender)
		NSApp.activate(ignoringOtherApps: true)
	}
		
	@IBAction func showPreferences(_ sender: Any) {
		readStatusItemOrder()
		if preferencesWindowController == nil {
			preferencesWindowController = NSStoryboard.main?.instantiateController(withIdentifier: "preferencesWindow") as? NSWindowController
		}
		NSApp.setActivationPolicy(.regular)
		preferencesWindowController?.showWindow(sender)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	@IBAction func showAboutPanel(_ sender: Any) {
		NSApp.orderFrontStandardAboutPanel(sender)
		NSApp.activate(ignoringOtherApps: true)
	}
	
	private func refreshActivationPolicy() {
		if ApplicationPreferences.activationPolicy == .regular {
			NSApp.setActivationPolicy(.regular)
		}
		else {
			NSApp.setActivationPolicy(.accessory)
		}
	}

	private func refreshLaunchAtLogin() {
		SMLoginItemSetEnabled("com.whetstoneapps.drilldown.launcher" as CFString, ApplicationPreferences.launchAtLogin)
	}
	
	func isCommandKeyPressed() -> Bool {
		return NSEvent.modifierFlags.contains(.command)
	}
	
	private func readStatusItemOrder() {
		let configs = ApplicationPreferences.loadMenuConfigurations()
		
		let sortedConfigurations = configs.sorted { (a, b) -> Bool in
			guard let controler_a = menuControllers[a], let controller_b = menuControllers[b] else {
				return false
			}
			
			return controler_a.screenX < controller_b.screenX
		}
		ApplicationPreferences.saveMenuConfigurations(sortedConfigurations)
	}
	
	// MARK: - AppStoreControllerDelegate
	
	struct ProductID {
		static let drill_down_full_iap_mac_01 = "drill_down_full_iap_mac_01"
	}

	func appStoreControllerPurchaseDidSucceed() {
		checkForPurchase()
	}

	func appStoreControllerRestoreDidSucceed() {
		checkForPurchase()
	}
	
	func appStoreControllerDidCancelPurchase() {
		NotificationCenter.default.post(name: AppDelegate.purchaseCanceledNotification, object: nil)
	}
	
	func appStoreControllerReceiptRefreshDidSucceed() {
		appStoreController.connectToStore()
		checkForPurchase()
	}

	func appStoreControllerDidReceiveMessage(_ message: String) {
		let alert = NSAlert()
		alert.messageText = NSLocalizedString("App Store Message", comment: "alert title")
		alert.informativeText = message
		alert.addButton(withTitle: NSLocalizedString("OK", comment: "button"))
		let _ = alert.runModal()
	}
	
	private func checkForPurchase() {
		let result = ReceiptValidator().validateReceipt()
		switch result {
		case .success(let receipt):
			AppDelegate.fullFeaturesPurchased = false
			for purchase in receipt.inAppPurchaseReceipts ?? [] {
				if purchase.productIdentifier == ProductID.drill_down_full_iap_mac_01 {
					AppDelegate.fullFeaturesPurchased = true
					break
				}
			}
		case .error:
			AppDelegate.fullFeaturesPurchased = false
		}
		
		NotificationCenter.default.post(name: AppDelegate.fullFeaturesPurchasedChangedNotification, object: nil)
	}
}
