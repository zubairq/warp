import Foundation
import Cocoa

private class QBEResizableTabletView: QBEResizableView {
	let tabletController: QBEChainViewController
	
	init(frame: CGRect, controller: QBEChainViewController) {
		tabletController = controller
		super.init(frame: frame)
	}

	required init?(coder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
}

class QBEDocumentViewController: NSViewController, QBEChainViewDelegate, QBEDocumentViewDelegate, QBEResizableDelegate {
	var document: QBEDocument? { didSet {
		self.documentView.subviews.each({($0 as? NSView)?.removeFromSuperview()})
		if let d = document {
			for tablet in d.tablets {
				self.addTablet(tablet)
			}
		}
	} }
	
	private var documentView: QBEDocumentView!
	private var configurator: QBEConfiguratorViewController? = nil
	@IBOutlet var addTabletMenu: NSMenu!
	@IBOutlet var workspaceView: NSScrollView!
	@IBOutlet var formulaField: NSTextField!
	
	private var formulaFieldCallback: ((QBEValue) -> ())?
	
	internal var locale: QBELocale { get {
		return QBEAppDelegate.sharedInstance.locale ?? QBELocale()
	} }
	
	func chainViewDidClose(view: QBEChainViewController) {
		if let t = view.chain?.tablet {
			removeTablet(t)
		}
	}
	
	func chainView(view: QBEChainViewController, configureStep: QBEStep?, delegate: QBESuggestionsViewDelegate) {
		self.configurator?.configure(configureStep, delegate: delegate)
	}
	
	func chainView(view: QBEChainViewController, editValue: QBEValue, callback: ((QBEValue) -> ())?) {
		setFormula(editValue, callback: callback)
	}
	
	private func setFormula(value: QBEValue, callback: ((QBEValue) -> ())?) {
		formulaField.enabled = callback != nil
		formulaField.stringValue = value.stringValue ?? ""
		formulaFieldCallback = callback
	}
	
	func removeTablet(tablet: QBETablet) {
		assert(tablet.document == document, "tablet should belong to our document")

		document?.removeTablet(tablet)
		self.configurator?.configure(nil, delegate: nil)
		
		for subview in documentView.subviews {
			if let rv = subview as? QBEResizableTabletView {
				if let ct = rv.tabletController.chain?.tablet where ct == tablet {
					subview.removeFromSuperview()
				}
			}
		}
		tabletsChanged()
		
		(undoManager?.prepareWithInvocationTarget(self) as? QBEDocumentViewController)?.addTablet(tablet, atLocation: nil)
		undoManager?.setActionName(NSLocalizedString("Remove tablet", comment: ""))
	}
	
	func addTablet(tablet: QBETablet, atLocation location: CGPoint? = nil) {
		// Check if this tablet is also in the document
		if let d = document where tablet.document != document {
			d.addTablet(tablet)
		}
		
		// By default, tablets get a size that (when at 100% zoom) fills about 61% horizontally/vertically
		if tablet.frame == nil {
			let vr = self.workspaceView.documentVisibleRect
			let defaultWidth: CGFloat = vr.size.width * 0.619 * self.workspaceView.magnification
			let defaultHeight: CGFloat = vr.size.height * 0.619 * self.workspaceView.magnification
			tablet.frame = CGRectMake(vr.origin.x + (vr.size.width - defaultWidth) / 2, vr.origin.y + (vr.size.height - defaultHeight) / 2, defaultWidth, defaultHeight)
		}
		
		if let l = location {
			tablet.frame = tablet.frame!.centeredAt(l)
		}
		
		if let tabletController = self.storyboard?.instantiateControllerWithIdentifier("chain") as? QBEChainViewController {
			tabletController.delegate = self

			self.addChildViewController(tabletController)
			tabletController.chain = tablet.chain
			tabletController.view.frame = tablet.frame!
			
			let resizer = QBEResizableTabletView(frame: tablet.frame!, controller: tabletController)
			resizer.contentView = tabletController.view
			resizer.delegate = self
			
			documentView.addTablet(resizer)
			tabletsChanged()
			selectView(resizer)
		}
	}
	
	private var selectedView: QBEResizableTabletView? { get {
		for vw in documentView.subviews {
			if let tv = vw as? QBEResizableTabletView {
				if tv.selected {
					return tv
				}
			}
		}
		return nil
	}}
	
	private var boundsOfAllTablets: CGRect? { get {
		// Find out the bounds of all tablets combined
		var allBounds: CGRect? = nil
		for vw in documentView.subviews {
			if let tv = vw as? QBEResizableTabletView {
				allBounds = allBounds == nil ? tv.frame : CGRectUnion(allBounds!, tv.frame)
			}
		}
		return allBounds
	} }
	
	@IBAction func zoomAll(sender: NSObject) {
		if let ab = boundsOfAllTablets {
			self.workspaceView.magnifyToFitRect(ab)
		}
	}
	
	@IBAction func zoomSelection(sender: NSObject) {
		if let selected = selectedView {
			self.workspaceView.magnifyToFitRect(selected.frame)
		}
	}
	
	// Call whenever tablets are added/removed or resized
	private func tabletsChanged() {
		if let ab = boundsOfAllTablets {
			// Determine new size of the document
			var newBounds = ab.rectByInsetting(dx: -100, dy: -100)
			let offset = CGPointMake(-newBounds.origin.x, -newBounds.origin.y)
			newBounds.offset(dx: offset.x, dy: offset.y)
			
			newBounds.size.width = max(self.workspaceView.bounds.size.width, newBounds.size.width)
			newBounds.size.height = max(self.workspaceView.bounds.size.height, newBounds.size.height)
			
			// Move all tablets
			for vw in documentView.subviews {
				if let tv = vw as? QBEResizableTabletView {
					if let tablet = tv.tabletController.chain?.tablet {
						if let tabletFrame = tablet.frame {
							tablet.frame = tabletFrame.rectByOffsetting(dx: offset.x, dy: offset.y)
							tv.frame = tablet.frame!
						}
					}
				}
			}
			
			// Set new document bounds
			let newBoundsVisible = self.documentView.visibleRect.rectByOffsetting(dx: -offset.x, dy: -offset.y)
			documentView.frame = CGRectMake(0, 0, newBounds.size.width, newBounds.size.height)
			workspaceView.scrollRectToVisible(newBoundsVisible)
			workspaceView.flashScrollers()
		}
	}
	
	func resizableView(view: QBEResizableView, changedFrameTo frame: CGRect) {
		if let tv = view as? QBEResizableTabletView {
			if let tablet = tv.tabletController.chain?.tablet {
				tablet.frame = frame
				tabletsChanged()
				if tv.selected {
					tv.scrollRectToVisible(tv.bounds)
				}
			}
		}
	}
	
	private func selectView(view: QBEResizableView?) {
		// Deselect other views
		for sv in documentView.subviews {
			if let tv = sv as? QBEResizableTabletView {
				tv.selected = (tv == view)
			}
		}
		
		// Move selected view to front
		if let tv = view as? QBEResizableTabletView {
			let complete = {() -> () in
				tv.scrollRectToVisible(tv.bounds)
				self.setFormula(QBEValue.InvalidValue, callback: nil)
				tv.tabletController.tabletWasSelected()
			}
			
			if self.workspaceView.magnification != 1.0 {
				NSAnimationContext.beginGrouping()
				NSAnimationContext.currentContext().duration = 0.5
				
				NSAnimationContext.currentContext().completionHandler = complete
				self.workspaceView.animator().magnification = 1.0
				tv.selected = true
				NSAnimationContext.endGrouping()
			}
			else {
				complete()
			}
		}
	}
	
	func resizableViewWasSelected(view: QBEResizableView) {
		selectView(view)
	}
	
	@IBAction func updateFromFormulaField(sender: NSObject) {
		if let fc = formulaFieldCallback {
			fc(locale.valueForLocalString(formulaField.stringValue))
		}
	}
	
	@IBAction func paste(sender: NSObject) {
		// Pasting a step?
		let pboard = NSPasteboard.generalPasteboard()
		if let data = pboard.dataForType(QBEStep.dragType) {
			if let step = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? QBEStep {
				self.addTablet(QBETablet(chain: QBEChain(head: step)))
			}
		}
		else {
			// No? Maybe we're pasting TSV/CSV data...
			var data = pboard.stringForType(NSPasteboardTypeString)
			if data == nil {
				data = pboard.stringForType(NSPasteboardTypeTabularText)
			}
			
			if let tsvString = data {
				var data: [QBERow] = []
				var headerRow: QBERow? = nil
				let rows = tsvString.componentsSeparatedByString("\r")
				for row in rows {
					var rowValues: [QBEValue] = []
					
					let cells = row.componentsSeparatedByString("\t")
					for cell in cells {
						rowValues.append(locale.valueForLocalString(cell))
					}
					
					if headerRow == nil {
						headerRow = rowValues
					}
					else {
						data.append(rowValues)
					}
				}
				
				if headerRow != nil {
					let raster = QBERaster(data: data, columnNames: headerRow!.map({return QBEColumn($0.stringValue!)}), readOnly: false)
					let s = QBERasterStep(raster: raster)
					let tablet = QBETablet(chain: QBEChain(head: s))
					addTablet(tablet)
				}
			}
		}
	}
	
	@IBAction func addButtonClicked(sender: NSView) {
		NSMenu.popUpContextMenu(self.addTabletMenu, withEvent: NSApplication.sharedApplication().currentEvent!, forView: self.view)
	}
	
	func documentView(view: QBEDocumentView, didReceiveFiles files: [String], atLocation: CGPoint) {
		var offset: CGPoint = CGPointMake(0,0)
		for file in files {
			if let url = NSURL(fileURLWithPath: file) {
				addTabletFromURL(url, atLocation: atLocation.offsetBy(offset))
				offset = offset.offsetBy(CGPointMake(25,-25))
			}
		}
	}
	
	func documentViewDidClickNowhere(view: QBEDocumentView) {
		selectView(nil)
	}
	
	private func addTabletFromURL(url: NSURL, atLocation: CGPoint? = nil) {
		QBEAsyncBackground {
			let sourceStep = QBEFactory.sharedInstance.stepForReadingFile(url)
			
			QBEAsyncMain {
				if sourceStep != nil {
					let tablet = QBETablet(chain: QBEChain(head: sourceStep))
					self.addTablet(tablet, atLocation: atLocation)
				}
				else {
					let alert = NSAlert()
					alert.messageText = NSLocalizedString("Unknown file format: ", comment: "") + (url.pathExtension ?? "")
					alert.alertStyle = NSAlertStyle.WarningAlertStyle
					alert.beginSheetModalForWindow(self.view.window!, completionHandler: { (result: NSModalResponse) -> Void in
						// Do nothing...
					})
				}
			}
		}
	}
	
	@IBAction func addTabletFromFile(sender: NSObject) {
		let no = NSOpenPanel()
		no.canChooseFiles = true
		no.allowedFileTypes = QBEFactory.sharedInstance.fileTypesForReading
		
		no.beginSheetModalForWindow(self.view.window!, completionHandler: { (result: Int) -> Void in
			if result==NSFileHandlingPanelOKButton {
				if let url = no.URLs[0] as? NSURL {
					self.addTabletFromURL(url)
				}
			}
		})
	}
	
	@IBAction func addTabletFromPresto(sender: NSObject) {
		self.addTablet(QBETablet(chain: QBEChain(head: QBEPrestoSourceStep())))
	}
	
	@IBAction func addTabletFromMySQL(sender: NSObject) {
		let s = QBEMySQLSourceStep(host: "127.0.0.1", port: 3306, user: "root", password: "", database: "test", tableName: "test")
		self.addTablet(QBETablet(chain: QBEChain(head: s)))
	}
	
	override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "configurator" {
			self.configurator = segue.destinationController as? QBEConfiguratorViewController
		}
	}
	
	func validateUserInterfaceItem(item: NSValidatedUserInterfaceItem) -> Bool {
		if item.action() == Selector("addButtonClicked:") { return true }
		if item.action() == Selector("addTabletFromFile:") { return true }
		if item.action() == Selector("addTabletFromPresto:") { return true }
		if item.action() == Selector("addTabletFromMySQL:") { return true }
		if item.action() == Selector("updateFromFormulaField:") { return true }
		if item.action() == Selector("zoomAll:") { return boundsOfAllTablets != nil }
		if item.action() == Selector("zoomSelection:") { return boundsOfAllTablets != nil }
		if item.action() == Selector("delete:") { return true }
		if item.action() == Selector("paste:") {
			let pboard = NSPasteboard.generalPasteboard()
			if pboard.dataForType(QBEStep.dragType) != nil || pboard.dataForType(NSPasteboardTypeString) != nil || pboard.dataForType(NSPasteboardTypeTabularText) != nil {
				return true
			}
		}
		return false
	}
	
	override func viewDidLoad() {
		documentView = QBEDocumentView(frame: CGRectMake(0, 0, 1337, 1337))
		documentView.delegate = self
		self.workspaceView.documentView = documentView
		tabletsChanged()
	}
}