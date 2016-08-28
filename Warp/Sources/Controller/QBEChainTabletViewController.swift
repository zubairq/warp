import Cocoa
import WarpCore

class QBEValueConfigurable: NSObject, QBEConfigurable {
	var value: Value

	var locale: Language {
		return QBEAppDelegate.sharedInstance.locale
	}

	init(value: Value) {
		self.value = value
	}

	func sentence(_ locale: Language, variant: QBESentenceVariant) -> QBESentence {
		return QBESentence([
			QBESentenceLabelToken(locale.localStringFor(self.value))
		])
	}
}

class QBEChangeableValueConfigurable: NSObject, QBEFullyConfigurable {
	var value: Value
	let callback: @escaping (Value) -> ()
	var locale: Language {
		return QBEAppDelegate.sharedInstance.locale
	}

	init(value: Value, callback: @escaping (Value) -> ()) {
		self.value = value
		self.callback = callback
	}

	func setSentence(_ sentence: QBESentence) {
		if let text = sentence.tokens.first {
			self.value = locale.valueForLocalString(text.label)
			self.callback(self.value)
		}
		else {
			self.callback(Value.empty)
		}
	}

	func sentence(_ locale: Language, variant: QBESentenceVariant) -> QBESentence {
		return QBESentence([
				QBESentenceLabelToken(locale.localStringFor(self.value))
		])
	}
}

internal class QBEChainTabletViewController: QBETabletViewController, QBEChainViewControllerDelegate {
	var chainViewController: QBEChainViewController? = nil { didSet { bind() } }

	override func tabletWasDeselected() {
		self.chainViewController?.selected = false
	}

	override func tabletWasSelected() {
		self.chainViewController?.selected = true
	}

	private func bind() {
		self.chainViewController?.chain = (self.tablet as! QBEChainTablet).chain
		self.chainViewController?.delegate = self
	}

	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		if segue.identifier == "chain" {
			self.chainViewController = segue.destinationController as? QBEChainViewController
		}
	}

	override func selectArrow(_ arrow: QBETabletArrow) {
		if let s = arrow.fromStep, s != self.chainViewController?.currentStep {
			self.chainViewController?.currentStep = s
			self.chainViewController?.calculate()
		}
	}

	override func startEditing() {
		self.chainViewController?.startEditing(self)
	}

	/** Chain view delegate implementation */
	func chainViewDidClose(_ view: QBEChainViewController) -> Bool {
		return self.delegate?.tabletViewDidClose(self) ?? true
	}

	func chainView(_ view: QBEChainViewController, editValue value: Value, changeable: Bool, callback: @escaping (Value) -> ()) {
		if changeable {
			self.delegate?.tabletView(self, didSelectConfigurable: QBEChangeableValueConfigurable(value: value, callback: callback), configureNow: false, delegate: nil)
		}
		else {
			self.delegate?.tabletView(self, didSelectConfigurable: QBEValueConfigurable(value: value), configureNow: false, delegate: nil)
		}
	}

	func chainView(_ view: QBEChainViewController, configureStep step: QBEStep?, necessary: Bool, delegate: QBESentenceViewDelegate) {
		self.delegate?.tabletView(self, didSelectConfigurable:step, configureNow: necessary, delegate: delegate)
	}

	func chainViewDidChangeChain(_ view: QBEChainViewController) {
		self.delegate?.tabletViewDidChangeContents(self)
	}

	func chainView(_ view: QBEChainViewController, exportChain chain: QBEChain) {
		self.delegate?.tabletView(self, exportObject: chain)
	}
}
