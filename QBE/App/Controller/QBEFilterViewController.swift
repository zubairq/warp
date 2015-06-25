import Cocoa

protocol QBEFilterViewDelegate: NSObjectProtocol {
	func filterView(view: QBEFilterViewController, applyFilter: QBEFilterSet?, permanent: Bool)
}

class QBEFilterViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	@IBOutlet var searchField: NSSearchField?
	@IBOutlet var valueList: NSTableView?
	weak var delegate: QBEFilterViewDelegate?
	
	var data: QBEData? { didSet {
		reloadData()
	} }
	var column: QBEColumn? { didSet {
		reloadData()
	} }
	
	private var reloadJob: QBEJob? = nil
	private var values: [QBEValue] = []
	
	var filter: QBEFilterSet = QBEFilterSet() { didSet {
		reloadData()
	} }
	
	private func reloadData() {
		reloadJob?.cancel()
		reloadJob = nil
		
		if let d = data, let c = column {
			var filteredData = d
			if let search = searchField?.stringValue where !search.isEmpty {
				filteredData = filteredData.filter(QBEBinaryExpression(first: QBELiteralExpression(QBEValue(search)), second: QBESiblingExpression(columnName: c), type: QBEBinary.MatchesRegex))
			}
			
			reloadJob = QBEJob(QBEQoS.UserInitiated)
			filteredData.unique(QBESiblingExpression(columnName: c), job: reloadJob!, callback: { (fallibleValues) -> () in
				switch fallibleValues {
					case .Success(let values):
						self.values = Array(values)
						self.values.sortInPlace({return $0.stringValue < $1.stringValue})
						QBEAsyncMain {
							self.valueList?.reloadData()
						}
					
					case .Failure(let e):
						QBELog("Error fetching unique values: \(e)")
				}
			})
		}
	}
	
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return values.count
	}
	
	func tableView(tableView: NSTableView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, row: Int) {
		if row < values.count {
			switch tableColumn?.identifier ?? "" {
				case "selected":
					if let b = object?.boolValue where b {
						filter.selectedValues.insert(values[row])
					}
					else {
						filter.selectedValues.remove(values[row])
					}
					filterChanged()
				
				default:
					break // Ignore
			}
		}
	}
	
	func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
		if row < values.count {
			switch tableColumn?.identifier ?? "" {
				case "value":
					return values[row].stringValue ?? ""
				
				case "selected":
					return NSNumber(bool: filter.selectedValues.contains(values[row]))
				
				default:
					return nil
			}
		}
		return nil
	}
	
	@IBAction func applyFilter(sender: NSObject) {
		self.delegate?.filterView(self, applyFilter: filter.selectedValues.count > 0 ? filter : nil, permanent: false)
	}
	
	@IBAction func searchChanged(sender: NSObject) {
		reloadData()
	}
	
	@IBAction func addFilterAsStep(sender: NSObject) {
		if filter.selectedValues.count > 0 {
			self.delegate?.filterView(self, applyFilter: filter, permanent: true)
		}
	}
	
	private func filterChanged() {
		self.valueList?.reloadData()
	}
	
	@IBAction override func selectAll(sender: AnyObject?) {
		filter.selectedValues.unionInPlace(values)
		self.valueList?.reloadData()
		filterChanged()
	}
	
	@IBAction func selectNone(sender: AnyObject?) {
		filter.selectedValues.subtractInPlace(values)
		self.valueList?.reloadData()
		filterChanged()
	}
	
	@IBAction func clearFilter(sender: NSObject) {
		self.searchField?.stringValue = ""
		filter.selectedValues = []
		self.delegate?.filterView(self, applyFilter: nil, permanent: false)
		reloadData()
		filterChanged()
	}
}