//
//  PreferencesViewController.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/16/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSPopoverDelegate, NSUserInterfaceValidations {

	@IBOutlet var tableView: NSTableView!
	@IBOutlet var removeButton: NSButton!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var launchAtLoginCheckbox: NSButton!
	@IBOutlet var showDockIconCheckbox: NSButton!
	@IBOutlet var emptyView: EmptyDropView!
	@IBOutlet var maximumLabel: NSTextField!
	
	private let menuConfigPasteboardType = NSPasteboard.PasteboardType(rawValue: "com.whetstone.drilldown.menuConfig")
	static let configurationChangedNotification = NSNotification.Name(rawValue: "configurationChanged")
	
	var menuConfigs: [DrillMenuConfiguration] = []

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(statusItemRemovedNotification(_:)), name: DrillMenuController.statusItemRemovedNotification, object: nil)

		tableView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, menuConfigPasteboardType])
	}
	

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		if item.action == #selector(changedTitleStyle(_:)) {
			if let menuItem = item as? NSMenuItem, let menu = menuItem.menu {
				let iconAndTitleItem = menu.item(at: DrillMenuConfiguration.TitleStyle.iconAndTitle.rawValue)!
				let titleOnlyItem = menu.item(at: DrillMenuConfiguration.TitleStyle.titleOnly.rawValue)!
				let titleOptionIsAlreadySelected = iconAndTitleItem.state == .on || titleOnlyItem.state == .on
				if numberOfConfigsWithLabels >= maxAllowedConfigsWithTitles && titleOptionIsAlreadySelected == false {
					let index = menu.index(of: menuItem)
					if index == DrillMenuConfiguration.TitleStyle.iconAndTitle.rawValue ||
						index == DrillMenuConfiguration.TitleStyle.titleOnly.rawValue {
						return false
					}
				}
			}
		}
		
		return true
	}
	
	private let maxAllowedConfigs = 10
	private let maxAllowedConfigsWithTitles = 5
	
	private var numberOfConfigsWithLabels: UInt {
		return menuConfigs.reduce(0) { (number, config) -> UInt in
			if config.titleStyle == .iconAndTitle || config.titleStyle == .titleOnly {
				return number + 1
			}
			else {
				return number
			}
		}
	}
	
	private func updateMaximum() {
		maximumLabel.isHidden = menuConfigs.count < maxAllowedConfigs && numberOfConfigsWithLabels < maxAllowedConfigsWithTitles
		addButton.isEnabled = menuConfigs.count < maxAllowedConfigs
	}
	
	override func viewWillAppear() {
		menuConfigs = ApplicationPreferences.loadMenuConfigurations()
		updateMaximum()
		emptyView.isHidden = menuConfigs.count > 0
		launchAtLoginCheckbox.state = ApplicationPreferences.launchAtLogin ? .on : .off
		showDockIconCheckbox.state = ApplicationPreferences.activationPolicy == .regular ? .on : .off
		tableView.reloadData()
	}
	
	override func viewWillDisappear() {
		super.viewWillDisappear()
	}
	
	private func saveConfiguration() {
		updateMaximum()
		ApplicationPreferences.saveMenuConfigurations(menuConfigs)
		NotificationCenter.default.post(name: PreferencesViewController.configurationChangedNotification, object: nil)
	}
	
	// MARK: - Actions
	
	@IBAction func addConfiguration(_ sender: Any) {
		guard let window = self.view.window else {
			return
		}
		
		// TODO after adding, rearrange from status item order
		
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.prompt = NSLocalizedString("Select a Menu Location…", comment: "open panel")
		panel.beginSheetModal(for: window) { (response) in
			guard response == .OK, let url = panel.url, let bookmark = DrillMenuConfiguration.securityScopedBookmark(from: url) else {
				return
			}
			
			let initialTitle = url.lastPathComponent
			let showFirstRun = self.menuConfigs.isEmpty
			let config = DrillMenuConfiguration(title: initialTitle, folderURLBookmark: bookmark)
			if self.numberOfConfigsWithLabels >= self.maxAllowedConfigsWithTitles {
				config.titleStyle = .iconOnly
			}
			self.menuConfigs.append(config)

			self.emptyView.isHidden = self.menuConfigs.count > 0
			self.tableView.reloadData()
			self.tableView.editColumn(0, row: self.menuConfigs.count - 1, with: nil, select: true)
			self.saveConfiguration()
			if showFirstRun {
				self.showFirstRunPopovers()
			}
		}
	}
	
	@IBAction func delete(_ sender: Any?) {
		removeConfiguration(self)
	}

	@IBAction func removeConfiguration(_ sender: Any) {
		guard tableView.selectedRow >= 0 && tableView.selectedRow < menuConfigs.count else {
			return
		}
		
		menuConfigs[tableView.selectedRow].stopAccessingSecurityScopedResource()
		menuConfigs.remove(at: tableView.selectedRow)
		
		emptyView.isHidden = menuConfigs.count > 0
		tableView.reloadData()
		saveConfiguration()
	}

	@IBAction func launchAtLogin(_ sender: Any) {
		ApplicationPreferences.launchAtLogin = launchAtLoginCheckbox.state == .on
	}
	
	@IBAction func showDockIcon(_ sender: Any) {
		ApplicationPreferences.activationPolicy = showDockIconCheckbox.state == .on ? .regular : .accessory
	}
	
	@objc func statusItemRemovedNotification(_ notification: Notification) {
		menuConfigs = ApplicationPreferences.loadMenuConfigurations()
		tableView.reloadData()
	}

	// MARK: - TableView
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return menuConfigs.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: nil)

		let config = menuConfigs[row]
		
		if let cell = cell as? TitleCellView {
			cell.textField?.stringValue = config.title
		}
		if let cell = cell as? PathCellView {
			if let path = config.nonSecurityScopedFolderPath {
				cell.pathControl?.url = URL(fileURLWithPath: path, isDirectory: true)
			}
		}
		if let cell = cell as? TitleStyleCellView {
			cell.titleStyleButton?.selectItem(at: config.titleStyle.rawValue)
		}
		if let cell = cell as? MenuIconsCellView {
			cell.menuIconStyleButton?.selectItem(at: config.menuIconStyle.rawValue)
		}
		if let cell = cell as? MenuFontCellView {
			cell.menuFontSizeButton?.selectItem(at: config.menuFontSize.rawValue)
		}
		if let cell = cell as? RichIconsCellView {
			switch config.useRichIcons {
			case .standard:
				cell.richIconsCheckbox?.state = .off
			case .rich:
				cell.richIconsCheckbox?.state = .on
			}
		}
		
		return cell
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		removeButton.isEnabled = (tableView.selectedRow != -1)
	}
	
//	func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
//		guard let row = rowIndexes.first else {
//			return false
//		}
//
//		if let pasteboardItem = NSPasteboardItem(pasteboardPropertyList: ["uuid" : menuConfigs[row].uuid], ofType: menuConfigPasteboardType) {
//			pboard.clearContents()
//			pboard.writeObjects([pasteboardItem])
//			return true
//		}
//		return false
//	}
	
	func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
		
		if let urls = urlsFromDraggingInfo(info) {
			if addButton.isEnabled == false {
				return []
			}
			
			for url in urls {
				var isDir: ObjCBool = false
				if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue == true {
//					tableView.setDropRow(0, dropOperation: .above)
//					tableView.setDropRow(row, dropOperation: .above)
					tableView.setDropRow(tableView.numberOfRows, dropOperation: .above)
					return .copy
				}
			}
		}
		
		if let _ = configUUIDFromDraggingInfo(info), dropOperation == .above {
			return .move
		}
		return []
	}
	
	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
		var success = false
		
		// TODO after adding, rearrange from status item order
		
		if let urls = urlsFromDraggingInfo(info) {
			for url in urls {
				var isDir: ObjCBool = false
				if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue == true {
					if addButton.isEnabled == false {
						break
					}
					
					if let bookmark = DrillMenuConfiguration.securityScopedBookmark(from: url) {
						let initialTitle = url.lastPathComponent
						let showFirstRun = self.menuConfigs.isEmpty
						let config = DrillMenuConfiguration(title: initialTitle, folderURLBookmark: bookmark)
						if numberOfConfigsWithLabels >= maxAllowedConfigsWithTitles {
							config.titleStyle = .iconOnly
						}
						menuConfigs.insert(config, at: row)

						emptyView.isHidden = menuConfigs.count > 0
						tableView.reloadData()
						tableView.editColumn(0, row: row, with: nil, select: true)
						saveConfiguration()
						if showFirstRun {
							showFirstRunPopovers()
						}
						success = true
					}
				}
			}
		}
		
		if let configUUID = configUUIDFromDraggingInfo(info) {
			if let droppedConfig = (menuConfigs.filter { $0.uuid == configUUID }.first), let oldRow = menuConfigs.firstIndex(of: droppedConfig) {
				if oldRow <= row {
					menuConfigs.insert(droppedConfig, at: row)
					menuConfigs.remove(at: oldRow)
				}
				else {
					menuConfigs.remove(at: oldRow)
					menuConfigs.insert(droppedConfig, at: row)
				}
				success = true
				tableView.reloadData()
				saveConfiguration()
			}
		}
		
		return success
	}
	
	private func urlsFromDraggingInfo(_ info: NSDraggingInfo) -> [URL]? {
		if let types = info.draggingPasteboard.types, types.contains(.fileURL), let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true]) as? [URL] {
			return urls
		}
		return nil
	}
	
	private func configUUIDFromDraggingInfo(_ info: NSDraggingInfo) -> String? {
		guard info.draggingPasteboard.canReadItem(withDataConformingToTypes: [menuConfigPasteboardType.rawValue]) else {
			return nil
		}
		
		if let types = info.draggingPasteboard.types, types.contains(menuConfigPasteboardType), let items = info.draggingPasteboard.readObjects(forClasses: [NSPasteboardItem.self], options: nil) as? [NSPasteboardItem], let item = items.first {
			if item.availableType(from: [menuConfigPasteboardType]) == menuConfigPasteboardType {
				if let plist = item.propertyList(forType: menuConfigPasteboardType) as? [String : String] {
					return plist["uuid"]
				}
			}
		}
		return nil
	}
	
	// MARK: - Table Cell Actions
	
	@IBAction func changedTitle(_ sender: Any) {
		guard let textField = sender as? NSTextField,
			let config = config(for: textField) else {
			return
		}
		
		config.title = textField.stringValue
		saveConfiguration()
	}
	
	@IBAction func changedTitleStyle(_ sender: Any) {
		guard let popUpButton = sender as? NSPopUpButton,
			let config = config(for: popUpButton) else {
			return
		}
		
		config.titleStyle = DrillMenuConfiguration.TitleStyle(rawValue: popUpButton.indexOfSelectedItem) ?? .iconAndTitle
		saveConfiguration()
	}
	
	@IBAction func changedMenuIconStyle(_ sender: Any) {
		guard let popUpButton = sender as? NSPopUpButton,
			let config = config(for: popUpButton) else {
			return
		}
		
		config.menuIconStyle = DrillMenuConfiguration.MenuIconStyle(rawValue: popUpButton.indexOfSelectedItem) ?? .smallIcons
		saveConfiguration()
	}
	
	@IBAction func changedMenuFontSize(_ sender: Any) {
		guard let popUpButton = sender as? NSPopUpButton,
			let config = config(for: popUpButton) else {
			return
		}
		
		config.menuFontSize = DrillMenuConfiguration.MenuFontSize(rawValue: popUpButton.indexOfSelectedItem) ?? .regular
		saveConfiguration()
	}
	
	@IBAction func changedRichIcons(_ sender: Any) {
		guard let checkbox = sender as? NSButton,
			let config = config(for: checkbox) else {
			return
		}
		
		config.useRichIcons = checkbox.state == .on ? DrillMenuConfiguration.RichIconStyle.rich : DrillMenuConfiguration.RichIconStyle.standard
		saveConfiguration()
	}
		
	private func config(for view: NSView) -> DrillMenuConfiguration? {
		let row = tableView.row(for: view)
		
		if row >= 0 && row < menuConfigs.count {
			return menuConfigs[row]
		}
		
		return nil
	}
	
	// MARK: - First Run Popovers
	
	func showFirstRunPopovers() {
		let popover = NSPopover()
		popover.contentViewController = NSStoryboard.main?.instantiateController(withIdentifier: "firstRunNamePopoverView") as? NSViewController
		popover.behavior = .transient
		popover.delegate = self
		
		if let view = tableView.view(atColumn: 0, row: 0, makeIfNecessary: false) {
			popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
		}
	}
	
	func popoverDidClose(_ notification: Notification) {
		if let popover = notification.object as? NSPopover, let identifier = popover.contentViewController?.view.identifier, identifier == NSUserInterfaceItemIdentifier("firstRunNamePopoverView") {
			if let appDelegate = NSApp.delegate as? AppDelegate {
				appDelegate.showFirstRunPopover()
			}
		}
	}
}

