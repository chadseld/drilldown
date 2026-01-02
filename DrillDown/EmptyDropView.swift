//
//  EmptyDropView.swift
//  Drill Down
//
//  Created by Chad Seldomridge on 1/30/20.
//  Copyright © 2020 Chad Seldomridge. All rights reserved.
//

import Cocoa

class EmptyDropView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

		let path = NSBezierPath(roundedRect: NSInsetRect(self.bounds, 30, 30), xRadius: 15, yRadius: 15)
		path.lineWidth = 6
		path.lineCapStyle = .round
		path.setLineDash([20, 10], count: 2, phase: 0)
		NSColor.tertiaryLabelColor.set()
		path.stroke()
    }
    
	override func hitTest(_ point: NSPoint) -> NSView? {
		return nil
	}
}
