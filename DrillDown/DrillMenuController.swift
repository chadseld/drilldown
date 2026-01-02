//
//  DrillMenuController.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/17/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

class DrillMenuController: NSObject {
	
	static let statusItemRemovedNotification = NSNotification.Name(rawValue: "statusItemRemoved")

	init(config: DrillMenuConfiguration) {
		self.config = config
		super.init()
		installStatusItem()
		updateWithNewConfiguration(config)
	}
	
	func updateWithNewConfiguration(_ config: DrillMenuConfiguration) {
		guard let statusItem = statusItem, let statusItemButton = statusItem.button, let url = config.securityScopedFolderURL else {
			return
		}

		self.config = config
		
		let length = (config.titleStyle == .iconOnly) ? NSStatusItem.squareLength : NSStatusItem.variableLength
		statusItem.length = length
		
		let icon = NSWorkspace.shared.icon(forFile: url.path)
		let height = (statusItemButton.frame.size.height) - 3
		icon.size = NSSize(width: height, height: height)
		
		switch config.titleStyle {
		case .iconAndTitle:
			statusItemButton.title = config.title
			statusItemButton.image = icon
			statusItemButton.imagePosition = .imageLeft
		case .iconOnly:
			statusItemButton.title = ""
			statusItemButton.image = icon
			statusItemButton.imagePosition = .imageOnly
		case .titleOnly:
			statusItemButton.title = config.title
			statusItemButton.image = nil
			statusItemButton.imagePosition = .noImage
		}
		
		statusItemButton.setAccessibilityTitle(config.title)
		statusItemButton.font = NSFont.systemFont(ofSize: 13)
		
		statusItem.autosaveName = config.uuid
		
		// Configure menu at root
		let menuController = DirectoryMenuController(parentMenuItem: nil, menu: NSMenu(), url: url, iconStyle: config.menuIconStyle, useRichIcons: config.useRichIcons, menuFontSize: config.menuFontSize)
		rootDirectoryController = menuController
		statusItem.menu = menuController.menu
	}
	
	private var isVisibleObservation: NSKeyValueObservation?
	
	func installStatusItem() {
		let length = (config.titleStyle == .iconOnly) ? NSStatusItem.squareLength : NSStatusItem.variableLength
		let statusItem = NSStatusBar.system.statusItem(withLength: length)

		guard let statusItemButton = statusItem.button else {
			NSStatusBar.system.removeStatusItem(statusItem)
			return
		}
		
		updateWithNewConfiguration(config)
		
		// observe status item isVisible over KVO. It will go false when teh user command drags it out of the menu. We will need to delete the config at that point.
		statusItem.behavior = .removalAllowed
		isVisibleObservation = statusItem.observe(\.isVisible) { [weak self] (statusItem, change) in
			if statusItem.isVisible == false, let config = self?.config {
				NotificationCenter.default.post(name: DrillMenuController.statusItemRemovedNotification, object: config)
			}
		}
		
		statusItemButton.addSubview(EventRoutingView(frame: statusItemButton.bounds, prepareForRightMouse: { [weak self] in
			self?.rootDirectoryController?.includeOptionsSection = true
		}, prepareForLeftMouse: { [weak self] in
			self?.rootDirectoryController?.includeOptionsSection = false
		}))
		
		self.statusItem = statusItem
	}
	
	func uninstallStatusItem() {
		if let statusItem = statusItem {
			NSStatusBar.system.removeStatusItem(statusItem)
			self.statusItem = nil
		}
	}
	
	func showPopover(_ popover: NSPopover) {
		if let button = statusItem?.button {
			popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
		}
	}
	
	var screenX: CGFloat {
		guard let button = statusItem?.button, let window = button.window else {
			return -1
		}
		return window.convertPoint(toScreen: button.convert(button.bounds.origin, to: nil)).x
	}
	
	deinit {
		uninstallStatusItem()
	}
	
	// MARK: - Private
	
	private var config: DrillMenuConfiguration
	private var statusItem: NSStatusItem?
	private var rootDirectoryController: DirectoryMenuController?
}

class EventRoutingView: NSView {
	init(frame frameRect: NSRect, prepareForRightMouse: @escaping () -> Void, prepareForLeftMouse: @escaping () -> Void) {
		self.prepareForRightMouse = prepareForRightMouse
		self.prepareForLeftMouse = prepareForLeftMouse
		super.init(frame: frameRect)
		self.autoresizingMask = [.width, .height]
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	let prepareForRightMouse: () -> Void
	let prepareForLeftMouse: () -> Void
	
	private func isOptionKeyPressed() -> Bool {
		return NSEvent.modifierFlags.contains(.option)
	}
	
	func isControlKeyPressed() -> Bool {
		return NSEvent.modifierFlags.contains(.control)
	}

	override func rightMouseDown(with event: NSEvent) {
		prepareForRightMouse()
		super.mouseDown(with: event)
	}
	
	override func mouseDown(with event: NSEvent) {
		if isOptionKeyPressed() || isControlKeyPressed() || event.type == .rightMouseDown {
			prepareForRightMouse()
		}
		else {
			prepareForLeftMouse()
		}
		super.mouseDown(with: event)
	}
}

fileprivate class DirectoryMenuController: NSObject, NSMenuDelegate {
	weak var parentMenuItem: NSMenuItem?
	let menu: NSMenu
	let url: URL?
	let iconStyle: DrillMenuConfiguration.MenuIconStyle
	let useRichIcons: DrillMenuConfiguration.RichIconStyle
	let menuFontSize: DrillMenuConfiguration.MenuFontSize
	var includeOptionsSection = false
	
	var submenuControllers: [URL : DirectoryMenuController] = [:]
	
	init(parentMenuItem: NSMenuItem?, menu: NSMenu, url: URL, iconStyle: DrillMenuConfiguration.MenuIconStyle, useRichIcons: DrillMenuConfiguration.RichIconStyle, menuFontSize: DrillMenuConfiguration.MenuFontSize) {
		self.parentMenuItem = parentMenuItem
		self.url = url
		self.menu = menu
		self.iconStyle = iconStyle
		self.useRichIcons = useRichIcons
		self.menuFontSize = menuFontSize
		super.init()
		menu.delegate = self
	}
	
	// MARK: - NSMenuDelegate
	
	private var quickLookTimer: Timer? = nil

//	NSTimer does not work here, because the menu is in its own run loop
//	func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
//		print("willHighlight \(String(describing: item?.title))")
//		quickLookTimer?.invalidate()
//		if let menuItem = item {
//			DispatchQueue.main.async {
//				self.quickLookTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(DirectoryMenuController.showQuickLook(_:)), userInfo: menuItem, repeats: false)
//			}
//		}
//	}
//
//	@objc func showQuickLook(_ timer: Timer) {
//		print("showQuickLook")
//	}
	
	func menuNeedsUpdate(_ menu: NSMenu) {
		
		// This is needed because of a bug in Cocoa (in NSStatusBar?) that causes
		// every node of the entire menu tree to be sent menu:updateItem:atIndex:shouldCancel:
		// when being triggered via the keyboard. This means that if you have 50,000 items in your
		// home folder, then every single item will be updated. This can take minutes, and thrash
		// memory usage up to >400MB. So, we override here and only report submenu items for the
		// highlited menu.
		if let parentMenuItem = parentMenuItem, parentMenuItem.isHighlighted == false {
			return
		}
		
		var contents: [MenuItem] = []
		
		if includeOptionsSection {
			contents.append(contentsOf: optionsSection())
		}
		
		do {
			let directoryContents = try fetchDirectoryContents()
			contents.append(contentsOf: directoryContents)
			
			if AppDelegate.fullFeaturesPurchased == false {
				contents.append(contentsOf: purchaseSection())
			}
		}
		catch let error {
			menu.removeAllItems()
			refreshMenuWithItemContents(optionsSection())
			menu.addItem(withTitle: error.localizedDescription, action: nil, keyEquivalent: "")
			menu.addItem(withTitle: "Add permission in System Preferences > Security & Privacy > Privacy > Files and Folders.", action: nil, keyEquivalent: "")
			return
		}
		
		if contents.isEmpty {
			menu.removeAllItems()
			menu.addItem(withTitle: "Empty", action: nil, keyEquivalent: "")
			return
		}
		
		refreshMenuWithItemContents(contents)
	}
	
	private func optionsSection() -> [MenuItem] {
		return [.option(Option(name: "About Drill Down…", action: #selector(AppDelegate.showAboutPanel(_:)))),
				.option(Option(name: "Preferences…", action: #selector(AppDelegate.showPreferences(_:)))),
				.option(Option(name: "Quit…", action: #selector(NSApp.terminate(_:)))),
				.separator]
	}
	
	private func purchaseSection() -> [MenuItem] {
		return [.separator,
				.option(Option(name: "Drill Down is limited to showing 10 items per menu", action: nil)),
				.option(Option(name: "Purchase Drill Down to Unlock Full Functionality", action: nil)),
				.option(Option(name: "Purchase Options…", action: #selector(AppDelegate.showPurchase(_:)))),
				.separator]
	}
	
	private func refreshMenuWithItemContents(_ contents: [MenuItem]) {
		let originalMenuItems = menu.items
		for (index, contentItem) in contents.enumerated() {
			switch contentItem {
			case .file(let file):
				let menuItem = getMenuItem(at: index)
				updateMenuItem(menuItem, with: file)
			case .option(let option):
				let menuItem = getMenuItem(at: index)
				updateMenuItem(menuItem, with: option)
			case .separator:
				_ = getSeparatorItem(at: index)
			}
		}
		
		if originalMenuItems.count > contents.count {
			for _ in contents.count ..< originalMenuItems.count {
				menu.removeItem(at: contents.count)
			}
		}
	}
	
	private func getMenuItem(at index: Int) -> NSMenuItem {
		if menu.numberOfItems > index, var menuItem = menu.item(at: index) {
			if menuItem.isSeparatorItem == false {
				return menuItem
			}
			else {
				menu.removeItem(at: index)
				menuItem = NSMenuItem()
				menu.insertItem(menuItem, at: index)
				return menuItem
			}
		}
		else {
			let menuItem = NSMenuItem()
			menu.addItem(menuItem)
			return menuItem
		}
	}
	
	private func getSeparatorItem(at index: Int) -> NSMenuItem {
		let menuItem: NSMenuItem
		if menu.numberOfItems > index, var menuItem = menu.item(at: index) {
			if menuItem.isSeparatorItem {
				return menuItem
			}
			else {
				menu.removeItem(at: index)
				menuItem = NSMenuItem.separator()
				menu.insertItem(menuItem, at: index)
				return menuItem
			}
		}
		else {
			menuItem = NSMenuItem.separator()
			menu.addItem(menuItem)
			return menuItem
		}
	}

	private var lastEventTime: TimeInterval = TimeInterval(0)
	private var lastDirectoryContents: [MenuItem] = []
	
	private func fetchDirectoryContents() throws -> [MenuItem] {
		guard let url = url else {
			return []
		}
		
		let currentEventTime = NSApp.currentEvent?.timestamp ?? TimeInterval(0)
		guard lastEventTime != currentEventTime else {
			print("returning contents from cache")
			return lastDirectoryContents;
		}
		
		let fileManager = FileManager.default
		
		let resourceValueKeys = Set<URLResourceKey>([
			URLResourceKey.nameKey,
			URLResourceKey.isPackageKey,
			URLResourceKey.isDirectoryKey,
			URLResourceKey.effectiveIconKey])

		var urlContents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(resourceValueKeys), options: .skipsHiddenFiles)
		
		if AppDelegate.fullFeaturesPurchased == false {
			urlContents = Array(urlContents.prefix(10))
		}
		
		var files: [MenuItem] = []
		for item in urlContents {
			let resourceValues = try item.resourceValues(forKeys: resourceValueKeys)

			
			let loadIcon: () -> NSImage? = {
				if self.useRichIcons == .rich || (resourceValues.isDirectory ?? false) || item.pathExtension.isEmpty {
					return resourceValues.effectiveIcon as? NSImage
				}
				else {
					return NSWorkspace.shared.icon(forFileType: item.pathExtension)
				}
			}
			
			let icon: NSImage?
			switch iconStyle {
			case .largeIcons:
				icon = loadIcon()
				icon?.size = NSSize(width: 32, height: 32)
			case .smallIcons:
				icon = loadIcon()
				if menuFontSize == .small {
					icon?.size = NSSize(width: 14, height: 14)
				}
				else {
					icon?.size = NSSize(width: 16, height: 16)
				}
			case .noIcons:
				icon = nil
			}
			
			if let name = resourceValues.name,
				let isDir = resourceValues.isDirectory,
				let isPackage = resourceValues.isPackage {
				files.append(.file(File(url: item,
								  name: name,
								  icon: icon,
								  isDir: isDir,
								  isPackage: isPackage)))
			}
			else {
				print("Failed to load resource values for url: \(item)")
				return []
			}
		}
		
		files = sortFiles(files)
		lastEventTime = currentEventTime
		lastDirectoryContents = files
		return files
	}

	static let largeFont_Attributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 16), NSAttributedString.Key.baselineOffset : NSNumber(value: -2)]
	static let regularFont_Attributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 14)]
	static let smallFont_Attributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 12)]

	static let largeFont_largeIconsAttributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 16), NSAttributedString.Key.baselineOffset : NSNumber(value: -2)]
	static let regularFont_largeIconsAttributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 14), NSAttributedString.Key.baselineOffset : NSNumber(value: -2)]
	static let smallFont_largeIconsAttributes = [NSAttributedString.Key.font : NSFont.menuFont(ofSize: 12), NSAttributedString.Key.baselineOffset : NSNumber(value: -4)]
	
	// TODO - other sort methods: date, type, date added.
	// TODO - other sort option: folders first, numbers first.
	
	private func sortFiles(_ files: [MenuItem]) -> [MenuItem] {
		return files.sorted { (a, b) -> Bool in
			switch (a, b) {
			case (.file(let aFile), .file (let bFile)):
				return aFile.name.localizedCompare(bFile.name) == .orderedAscending
			default:
				return false
			}
			
		}
	}
	
	private func attributedTitle(with title: String) -> NSAttributedString {
		switch menuFontSize {
		case .large:
			if iconStyle == .largeIcons {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.largeFont_largeIconsAttributes)
			}
			else {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.largeFont_Attributes)
			}
		case .regular:
			if iconStyle == .largeIcons {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.regularFont_largeIconsAttributes)
			}
			else {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.regularFont_Attributes)
			}
		case .small:
			if iconStyle == .largeIcons {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.smallFont_largeIconsAttributes)
			}
			else {
				return NSAttributedString(string: title, attributes: DirectoryMenuController.smallFont_Attributes)
			}
		}
	}
	
	func updateMenuItem(_ menuItem: NSMenuItem, with file: File) {
		menuItem.attributedTitle = attributedTitle(with: file.name)
		menuItem.image = file.icon
		menuItem.representedObject = file.url
		menuItem.target = nil
		menuItem.action = #selector(AppDelegate.menuItemSelected(_:))
		
		if file.isDir == true && file.isPackage == false {
			if let existingSubmenuController = submenuControllers[file.url], menuItem.submenu == existingSubmenuController.menu {
				// Do nothing, the submenu controller for this menu item is already correct.
			}
			else {
				let submenuController = DirectoryMenuController(parentMenuItem: menuItem, menu: NSMenu(), url: file.url, iconStyle: iconStyle, useRichIcons: useRichIcons, menuFontSize: menuFontSize)
				menuItem.submenu = submenuController.menu
				submenuControllers[file.url] = submenuController
			}
		}
		else {
			menuItem.submenu = nil
		}
	}
	
	func updateMenuItem(_ menuItem: NSMenuItem, with option: Option) {
		menuItem.image = nil
		menuItem.representedObject = nil
		menuItem.target = nil
		menuItem.action = option.action
		menuItem.attributedTitle = attributedTitle(with: option.name)
		menuItem.submenu = nil
	}
	
	struct File {
		let url: URL
		let name: String
		let icon: NSImage?
		let isDir: Bool
		let isPackage: Bool
	}
	
	struct Option {
		let name: String
		let action: Selector?
	}
	
	enum MenuItem {
		case file(File)
		case option(Option)
		case separator
	}
}
