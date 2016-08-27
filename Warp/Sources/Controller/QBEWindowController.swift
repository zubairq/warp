import Foundation
import Cocoa

internal class QBEWindowController: NSWindowController {
	override var document: AnyObject? {
		didSet {
			if let qbeDocumentViewController = window!.contentViewController as? QBEDocumentViewController {
				qbeDocumentViewController.document = document as? QBEDocument
				self.update()
			}
		}
	}

	internal func update() {
		let saved: Bool
		if let doc = self.document as? QBEDocument {
			saved = doc.savedAtLeastOnce || doc.fileURL != nil
		}
		else {
			saved = false
		}
		self.window?.titleVisibility =  saved ? .visible : .hidden
	}

	override func windowDidLoad() {
		self.update()
	}
}

class QBEToolbarItem: NSToolbarItem {
	var isValid: Bool {
		if let f = NSApp.target(forAction: #selector(NSObject.validateToolbarItem(_:))) as? NSResponder {
			var responder: NSResponder? = f

			while responder != nil {
				if responder!.responds(to: #selector(NSObject.validateToolbarItem(_:))) && responder!.validateToolbarItem(self) {
					return true
				}
				else {
					responder = responder?.nextResponder
				}
			}
			return false
		}
		else {
			return false
		}
	}

	override func validate() {
		self.isEnabled = isValid
		if let b = self.view as? NSButton {
			if !self.isEnabled {
				b.state = NSOffState
			}
		}
	}
}
