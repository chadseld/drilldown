//
//  AppDelegate.swift
//  Launcher
//
//  Created by Chad Seldomridge on 1/16/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let appInstances = NSRunningApplication.runningApplications(withBundleIdentifier: "com.whetstoneapps.drilldown")
		if appInstances.isEmpty {
			let appURL = Bundle.main.bundleURL.appendingPathComponent("../../../../Contents/MacOS/Drill Down", isDirectory: false).resolvingSymlinksInPath()
			do {
				try NSWorkspace.shared.launchApplication(at: appURL, options: .default, configuration: [:])
			}
			catch let error {
				print("Could not launch \(appURL). Error: \(error)")
			}
		}
		NSApp.terminate(self)
	}

}

