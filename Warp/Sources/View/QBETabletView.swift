import Cocoa

/** The view of a QBETabletViewController should subclass this view. It is used to identify pieces of the tablet that are
draggable (see QBEResizableView's hitTest). */
internal class QBETabletView: NSView {
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
	}

	override func drawRect(dirtyRect: NSRect) {
		NSColor.windowBackgroundColor().set()
		NSRectFill(dirtyRect)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func becomeFirstResponder() -> Bool {
		for sv in self.subviews {
			if sv.acceptsFirstResponder && self.window!.makeFirstResponder(sv) {
				return true
			}
		}
		return true // Tablet controller becomes first responder
	}

	override var allowsVibrancy: Bool { return true }
}