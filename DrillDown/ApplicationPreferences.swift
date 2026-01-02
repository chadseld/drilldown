//
//  ApplicationPreferences.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/17/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

class ApplicationPreferences: NSObject {

	enum ActivationPolicy: String {
		case regular = "regular"
		case accessory = "accessory"
	}
	
	static var activationPolicy: ActivationPolicy {
		get {
			if let raw = UserDefaults.standard.string(forKey: Keys.activationPolicy), let policy = ActivationPolicy(rawValue: raw) {
				return policy
			}
			else {
				return .regular
			}
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Keys.activationPolicy)
		}
	}
	
	static var launchAtLogin: Bool {
		get {
			UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin)
		}
	}
	
	static func loadMenuConfigurations() -> [DrillMenuConfiguration] {
		if let data = UserDefaults.standard.data(forKey: Keys.menuConfigurations),
			let configs = try? PropertyListDecoder().decode([DrillMenuConfiguration].self, from: data) {
			return configs
		}
		return []
	}

	static func saveMenuConfigurations(_ configs: [DrillMenuConfiguration]) {
		if let data = try? PropertyListEncoder().encode(configs) {
			UserDefaults.standard.set(data, forKey: Keys.menuConfigurations)
		}
	}
	
	// MARK: - Private
	
	private struct Keys {
		static let activationPolicy = "activationPolicy"
		static let launchAtLogin = "launchAtLogin"
		static let menuConfigurations = "menuConfigurations_v1"
	}
}
