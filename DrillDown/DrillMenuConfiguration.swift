//
//  DrillMenuConfiguration.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/17/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

class DrillMenuConfiguration: Codable, Equatable, Hashable {
	
	enum TitleStyle: Int, Codable {
		case iconAndTitle = 0
		case iconOnly
		case titleOnly
	}
	
	enum MenuIconStyle: Int, Codable {
		case smallIcons = 0
		case largeIcons
		case noIcons
	}
	
	enum RichIconStyle: Int, Codable {
		case rich = 0
		case standard
	}
	
	enum MenuFontSize: Int, Codable {
		case small = 0
		case regular
		case large
	}

	var version: Int = 1
	var uuid: String = NSUUID().uuidString
	
	var folderURLBookmark: Data
	
	var title: String
	var titleStyle: TitleStyle = .iconAndTitle
	var menuIconStyle: MenuIconStyle = .smallIcons
	var useRichIcons: RichIconStyle = .rich
	var menuFontSize: MenuFontSize = .regular
	
	init(title: String, folderURLBookmark: Data) {
		self.title = title
		self.folderURLBookmark = folderURLBookmark
	}
		
	static func securityScopedBookmark(from url: URL) -> Data? {
		return try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: [URLResourceKey.pathKey], relativeTo: nil)
	}
	
	var nonSecurityScopedFolderPath: String? {
		if let resourceValues = URL.resourceValues(forKeys: [URLResourceKey.pathKey], fromBookmarkData: folderURLBookmark) {
			return resourceValues.path
		}
		else {
			return nil
		}
	}
	
	var securityScopedFolderURL: URL? {
		if let existingURL = DrillMenuConfiguration.securityScopedURLCache[self] {
			return existingURL
		}
		else {
			var bookmarkIsStale = false
			if let url = try? URL(resolvingBookmarkData: folderURLBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkIsStale) {
				if url.startAccessingSecurityScopedResource() {
					DrillMenuConfiguration.securityScopedURLCache[self] = url
					return url
				}
			}
			return nil
		}
	}
	
	func stopAccessingSecurityScopedResource() {
		if let existingURL = DrillMenuConfiguration.securityScopedURLCache[self] {
			existingURL.stopAccessingSecurityScopedResource()
		}
		DrillMenuConfiguration.securityScopedURLCache.removeValue(forKey: self)
	}
	
	static func clearSecurityScopeAccessCache() {
		securityScopedURLCache.values.forEach { (url) in
			url.stopAccessingSecurityScopedResource()
		}
		securityScopedURLCache.removeAll()
	}
	
	static var securityScopedURLCache: [DrillMenuConfiguration : URL] = [:]
	
	static func == (lhs: DrillMenuConfiguration, rhs: DrillMenuConfiguration) -> Bool {
		return lhs.uuid == rhs.uuid
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(uuid)
	}
}
