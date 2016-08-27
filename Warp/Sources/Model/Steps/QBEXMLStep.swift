import Foundation
import WarpCore

class QBEXMLWriter: NSObject, QBEFileWriter, StreamDelegate {
	class var fileTypes: Set<String> { get { return Set<String>(["xml"]) } }

	var title: String?

	required init(locale: Language, title: String?) {
		self.title = title
	}

	required init?(coder aDecoder: NSCoder) {
		self.title = aDecoder.decodeString(forKey:"title")
	}

	func encode(with aCoder: NSCoder) {
		aCoder.encodeString(self.title ?? "", forKey: "title")
	}

	func sentence(_ locale: Language) -> QBESentence? {
		return nil
	}

	static func explain(_ fileExtension: String, locale: Language) -> String {
		return NSLocalizedString("XML", comment: "")
	}
	
	func writeDataset(_ data: Dataset, toFile file: URL, locale: Language, job: Job, callback: @escaping (Fallible<Void>) -> ()) {
		let stream = data.stream()
		
		if let writer = TCMXMLWriter(options: UInt(TCMXMLWriterOptionPrettyPrinted), fileURL: file) {
			writer.instructXML()
			writer.tag("graph", attributes: ["xmlns": "http://dialogicplatform.com/data/1.0"]) {
				writer.tag("status", attributes: [:], contentText: "ok")
				
				writer.tag("meta", attributes: [:]) {
					writer.tag("generated", attributes: [:], contentText: Date().iso8601FormattedUTCDate)
					writer.tag("system", attributes: [:], contentText: "Warp")
					writer.tag("domain", attributes: [:], contentText: Host.current().name ?? "localhost")
					writer.tag("input", attributes: [:], contentText: "")
				}
				
				writer.tag("details", attributes: [:]) {
					writer.tag("type", attributes: [:], contentText: "multidimensional")
					writer.tag("title", attributes: [:], contentText: self.title ?? "")
					writer.tag("source", attributes: [:], contentText: "")
					writer.tag("comment", attributes: [:], contentText: "")
				}
				
				writer.tag("axes", attributes: [:]) {
					writer.tag("axis", attributes: ["pos": "X1"]) { writer.text("X") }
					writer.tag("axis", attributes: ["pos": "Y1"]) { writer.text("Y") }
				}
				
				// Fetch column names
				stream.columns(job) { (columns) -> () in
					switch columns {
						case .success(let cns):
							writer.openTag("grid")
							
							// Write first row with column names
							writer.tag("row", attributes: [:]) {
								for cn in cns {
									writer.tag("cell", attributes: [:], contentText: cn.name)
								}
							}
							
							// Fetch rows in batches and write rows to XML
							var sink: Sink? = nil
							sink = { (rows: Fallible<Array<Tuple>>, streamStatus: StreamStatus) -> () in
								switch rows {
								case .success(let rs):
									// Write rows
									for row in rs {
										writer.tag("row", attributes: [:]) {
											for cell in row {
												writer.tag("cell", attributes: [:], contentText: cell.stringValue)
											}
										}
									}
									
									if streamStatus == .hasMore {
										job.async {
											stream.fetch(job, consumer: sink!)
										}
									}
									else {
										writer.closeLastTag()
										callback(.success())
									}
									
								case .failure(let e):
									callback(.failure(e))
								}
							}
							
							stream.fetch(job, consumer: sink!)
							
						case .failure(let e):
							callback(.failure(e))
					}
				}
			}
		}
	}
}
