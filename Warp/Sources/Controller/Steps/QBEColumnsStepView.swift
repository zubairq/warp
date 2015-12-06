import Foundation
import WarpCore

internal class QBEColumnsStepView: QBEStepViewControllerFor<QBEColumnsStep>, NSTableViewDataSource, NSTableViewDelegate {
	var columnNames: [QBEColumn] = []
	@IBOutlet var tableView: NSTableView?
	
	required init?(step: QBEStep, delegate: QBEStepViewDelegate) {
		super.init(step: step, delegate: delegate, nibName: "QBEColumnsStepView", bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("Should not be called")
	}
	
	internal override func viewWillAppear() {
		updateColumns()
		super.viewWillAppear()
		updateView()
	}
	
	private func updateColumns() {
		let job = QBEJob(.UserInitiated)
		if let previous = step.previous {
			previous.exampleData(job, maxInputRows: 100, maxOutputRows: 100) { (data) -> () in
				data.maybe({$0.columnNames(job) {(columns) in
					columns.maybe {(cns) in
						QBEAsyncMain {
							self.columnNames = cns
							self.updateView()
						}
					}
				}})
			}
		}
		else {
			columnNames.removeAll()
			self.updateView()
		}
	}
	
	private func updateView() {
		tableView?.reloadData()
	}
	
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return columnNames.count
	}
	
	func tableView(tableView: NSTableView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, row: Int) {
		if let identifier = tableColumn?.identifier where identifier == "selected" {
			let select = object?.boolValue ?? false
			let name = columnNames[row]
			step.columnNames.remove(name)
			if select {
				step.columnNames.append(name)
			}
		}
		self.delegate?.stepView(self, didChangeConfigurationForStep: step)
	}
	
	internal func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
		if let tc = tableColumn {
			if (tc.identifier ?? "") == "column" {
				return columnNames[row].name
			}
			else {
				return NSNumber(bool: step.columnNames.indexOf(columnNames[row]) != nil)
			}
		}
		return nil
	}
}