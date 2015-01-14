import Foundation

class QBELimitStep: QBEStep {
	var numberOfRows: Int
	
	init(previous: QBEStep?, explanation: String, numberOfRows: Int) {
		self.numberOfRows = numberOfRows
		super.init(previous: previous, explanation: explanation)
	}
	
	required init(coder aDecoder: NSCoder) {
		numberOfRows = Int(aDecoder.decodeIntForKey("numberOfRows"))
		super.init(coder: aDecoder)
	}
	
	override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
		coder.encodeInt(Int32(numberOfRows), forKey: "numberOfRows")
	}
	
	override func apply(data: QBEData?) -> QBEData? {
		return data?.limit(numberOfRows)
	}
}

class QBERandomStep: QBELimitStep {
	override init(previous: QBEStep?, explanation: String, numberOfRows: Int) {
		super.init(previous: previous, explanation: explanation, numberOfRows: numberOfRows)
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
	}
	
	override func apply(data: QBEData?) -> QBEData? {
		return data?.random(numberOfRows)
	}
}