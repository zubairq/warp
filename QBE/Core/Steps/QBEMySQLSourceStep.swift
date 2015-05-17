import Foundation

/** 
Implementation of the MySQL 'SQL dialect'. Only deviatons from the standard dialect are implemented here. */
private class QBEMySQLDialect: QBEStandardSQLDialect {
	override var identifierQualifier: String { get { return  "`" } }
	override var identifierQualifierEscape: String { get { return  "\\`" } }
	
	override func unaryToSQL(type: QBEFunction, args: [String]) -> String? {
		let value = args.implode(", ") ?? ""
		
		if type == QBEFunction.Random {
			return "RAND(\(value))"
		}
		return super.unaryToSQL(type, args: args)
	}
	
	private override func aggregationToSQL(aggregation: QBEAggregation, alias: String) -> String? {
		// For QBEFunction.Count, we should count numeric values only. In MySQL this can be done using REGEXP
		if aggregation.reduce == QBEFunction.Count {
			if let expressionSQL = expressionToSQL(aggregation.map, alias: alias) {
				return "SUM(CASE WHEN \(expressionSQL) REGEXP '^[[:digit:]]+$') THEN 1 ELSE 0 END)"
			}
			return nil
		}
		
		return super.aggregationToSQL(aggregation, alias: alias)
	}
	
	private override func forceStringExpression(expression: String) -> String {
		return "CAST(\(expression) AS BINARY)"
	}
	
	private override func forceNumericExpression(expression: String) -> String {
		return "CAST(\(expression) AS DECIMAL)"
	}
}

internal class QBEMySQLResult: SequenceType, GeneratorType {
	typealias Element = QBETuple
	typealias Generator = QBEMySQLResult
	
	private let connection: QBEMySQLConnection
	private let result: UnsafeMutablePointer<MYSQL_RES>
	private(set) var columnNames: [QBEColumn] = []
	private(set) var columnTypes: [MYSQL_FIELD] = []
	private(set) var finished = false
	
	init?(_ result: UnsafeMutablePointer<MYSQL_RES>, connection: QBEMySQLConnection) {
		self.result = result
		self.connection = connection
		
		// Get column names from result set
		var failed = false
		dispatch_sync(QBEMySQLConnection.sharedQueue) {
			let colCount = mysql_field_count(connection.connection)
			for colIndex in 0..<colCount {
				let column = mysql_fetch_field(self.result)
				if column != nil {
					if let name = NSString(bytes: column.memory.name, length: Int(column.memory.name_length), encoding: NSUTF8StringEncoding) {
						self.columnNames.append(QBEColumn(String(name)))
						self.columnTypes.append(column.memory)
					}
					else {
						failed = true
						return
					}
				}
				else {
					failed = true
					return
				}
			}
		}
		
		if failed {
			return nil
		}
	}
	
	func finish() {
		_finish(false)
	}
	
	private func _finish(warn: Bool) {
		if !self.finished {
			/* A new query cannot be started before all results from the previous one have been fetched, because packets
			will get out of order. */
			var n = 0
			while let x = self.row() {
				++n
			}
			
			#if DEBUG
				if warn && n > 0 {
					QBELog("Unfinished result was destroyed, drained \(n) rows to prevent packet errors. This is a performance issue!")
				}
			#endif
			self.finished = true
		}
	}
	
	deinit {
		_finish(true)
		
		let result = self.result
		dispatch_sync(QBEMySQLConnection.sharedQueue) {
			mysql_free_result(result)
			return
		}
	}
	
	func generate() -> Generator {
		return self
	}
	
	func next() -> Element? {
		return row()
	}
	
	func row() -> [QBEValue]? {
		var rowData: [QBEValue]? = nil
		
		dispatch_sync(QBEMySQLConnection.sharedQueue) {
			let row: MYSQL_ROW = mysql_fetch_row(self.result)
			if row != nil {
				rowData = []
				rowData!.reserveCapacity(self.columnNames.count)
				
				for cn in 0..<self.columnNames.count {
					let val = row[cn]
					if val == nil {
						rowData!.append(QBEValue.EmptyValue)
					}
					else {
						// Is this a numeric field?
						let type = self.columnTypes[cn]
						if (Int32(type.flags) & NUM_FLAG) != 0 {
							if type.type.value == MYSQL_TYPE_TINY.value
								|| type.type.value == MYSQL_TYPE_SHORT.value
								|| type.type.value == MYSQL_TYPE_LONG.value
								|| type.type.value == MYSQL_TYPE_INT24.value
								|| type.type.value == MYSQL_TYPE_LONGLONG.value {
									if let str = String(CString: val, encoding: NSUTF8StringEncoding), let nt = str.toInt() {
										rowData!.append(QBEValue.IntValue(nt))
									}
									else {
										rowData!.append(QBEValue.InvalidValue)
									}
									
							}
							else {
								if let str = String(CString: val, encoding: NSUTF8StringEncoding) {
									if let dbl = str.toDouble() {
										rowData!.append(QBEValue.DoubleValue(dbl))
									}
									else {
										rowData!.append(QBEValue.StringValue(str))
									}
								}
								else {
									rowData!.append(QBEValue.InvalidValue)
								}
							}
						}
						else {
							//let value = NSString(bytes: row, length: Int(column.memory.name_length), encoding: NSUTF8StringEncoding);
							if let str = String(CString: val, encoding: NSUTF8StringEncoding) {
								rowData!.append(QBEValue.StringValue(str))
							}
							else {
								rowData!.append(QBEValue.InvalidValue)
							}
						}
					}
				}
			}
			else {
				self.finished = true
			}
		}
		
		return rowData
	}
}

class QBEMySQLServer {
	private let host: String
	private let port: Int
	private let user: String
	private let password: String
	private let database: String
	private let dialect: QBESQLDialect = QBEMySQLDialect()
	
	init(host: String, port: Int, user: String, password: String, database: String) {
		self.host = host
		self.port = port
		self.user = user
		self.password = password
		self.database = database
	}
	
	var url: String { get {
		return NSURL(scheme: "mysql", host: "\(host):\(port)", path: "/\(user)")!.absoluteString!
	} }
}

/**
Implements a connection to a MySQL database (corresponding to a MYSQL object in the MySQL library). The connection ensures
that any operations are serialized (for now using a global queue for all MySQL operations). */
internal class QBEMySQLConnection {
	private(set) var server: QBEMySQLServer
	private var connection: UnsafeMutablePointer<MYSQL>
	private(set) weak var result: QBEMySQLResult?
	
	// TODO: make this a per-connection queue if the library is thread-safe per connection
	class var sharedQueue : dispatch_queue_t {
		struct Static {
			static var onceToken : dispatch_once_t = 0
			static var instance : dispatch_queue_t? = nil
		}
		dispatch_once(&Static.onceToken) {
			/* Mysql_library_init is what we should call, but as it is #defined to mysql_server_init, Swift doesn't see it. 
			So we just call mysql_server_int. */
			if mysql_server_init(0, nil, nil) == 0 {
				Static.instance = dispatch_queue_create("QBEMySQLConnection.Queue", DISPATCH_QUEUE_SERIAL)
				dispatch_set_target_queue(Static.instance, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
			}
			else {
				QBELog("Error initializing MySQL library")
			}
		}
		return Static.instance!
	}
	
	init?(server: QBEMySQLServer) {
		self.server = server
		self.connection = nil
		
		self.perform({() -> Int32 in
			self.connection = mysql_init(nil)
			mysql_real_connect(self.connection,
				self.server.host.cStringUsingEncoding(NSUTF8StringEncoding)!,
				self.server.user.cStringUsingEncoding(NSUTF8StringEncoding)!,
				self.server.password.cStringUsingEncoding(NSUTF8StringEncoding)!,
				nil,
				UInt32(self.server.port),
				UnsafePointer<Int8>(nil),
				UInt(0)
			)
			return Int32(mysql_errno(self.connection))
		})
		
		if let dbn = server.database.cStringUsingEncoding(NSUTF8StringEncoding) where !server.database.isEmpty {
			self.perform({() -> Int32 in
				return mysql_select_db(self.connection, dbn)
			})
		}
	}
	
	deinit {
		if connection != nil {
			dispatch_sync(QBEMySQLConnection.sharedQueue) {
				mysql_close(self.connection)
			}
		}
	}
	
	func clone() -> QBEMySQLConnection? {
		return QBEMySQLConnection(server: self.server)
	}
	
	func databases(callback: ([String]) -> ()) {
		if let r = self.query("SHOW DATABASES") {
			var dbs: [String] = []
			while let d = r.row() {
				if let name = d[0].stringValue {
					dbs.append(name)
				}
			}
			
			callback(dbs)
		}
	}
	
	func tables(callback: ([String]) -> ()) {
		if let r = self.query("SHOW TABLES") {
			var dbs: [String] = []
			while let d = r.row() {
				if let name = d[0].stringValue {
					dbs.append(name)
				}
			}
			
			callback(dbs)
		}
	}
	
	private func perform(block: () -> (Int32)) -> Bool {
		var success: Bool = false
		dispatch_sync(QBEMySQLConnection.sharedQueue) {
			let result = block()
			if result != 0 {
				let message = String(CString: mysql_error(self.connection), encoding: NSUTF8StringEncoding)
				QBELog("MySQL perform error: \(message)")
				success = false
			}
			success = true
		}
		return success
	}
	
	func query(sql: String) -> QBEMySQLResult? {
		if self.result != nil && !self.result!.finished {
			fatalError("Cannot start a query when the previous result is not finished yet")
		}
		self.result = nil
		
		#if DEBUG
			QBELog("MySQL Query \(sql)")
		#endif

		if self.perform({return mysql_query(self.connection, sql.cStringUsingEncoding(NSUTF8StringEncoding)!)}) {
			let result = QBEMySQLResult(mysql_use_result(self.connection), connection: self)
			self.result = result
			return result
		}
		return nil
	}
}

func == (lhs: QBEMySQLServer, rhs: QBEMySQLServer) -> Bool {
	return lhs.url == rhs.url
}

/** 
Represents the result of a MySQL query as a QBEData object. */
class QBEMySQLData: QBESQLData {
	private let server: QBEMySQLServer
	private let locale: QBELocale?
	
	private convenience init(server: QBEMySQLServer, tableName: String, locale: QBELocale?) {
		let query = "SELECT * FROM \(server.dialect.tableIdentifier(tableName)) LIMIT 1"
		let result = QBEMySQLConnection(server: server)?.query(query)
		result?.finish() // We're not interested in that one row we just requested, just the column names
		
		self.init(server: server, table: tableName, columns: result?.columnNames ?? [], locale: locale)
	}
	
	private init(server: QBEMySQLServer, fragment: QBESQLFragment, columns: [QBEColumn], locale: QBELocale?) {
		self.server = server
		self.locale = locale
		super.init(fragment: fragment, columns: columns)
	}
	
	private init(server: QBEMySQLServer, table: String, columns: [QBEColumn], locale: QBELocale?) {
		self.server = server
		self.locale = locale
		super.init(table: table, dialect: server.dialect, columns: columns)
	}
	
	override func apply(fragment: QBESQLFragment, resultingColumns: [QBEColumn]) -> QBEData {
		return QBEMySQLData(server: self.server, fragment: fragment, columns: resultingColumns, locale: locale)
	}
	
	override func stream() -> QBEStream {
		return QBEMySQLStream(data: self) ?? QBEEmptyStream()
	}
	
	private func result() -> QBEMySQLResult? {
		return QBEMySQLConnection(server: self.server)?.query(self.sql.sqlSelect(nil).sql)
	}
	
	override func isCompatibleWith(other: QBESQLData) -> Bool {
		if let om = other as? QBEMySQLData {
			if om.server == self.server {
				return true
			}
		}
		return false
	}
}

/**
QBEMySQLStream provides a stream of records from a MySQL result set. Because SQLite result can only be accessed once
sequentially, cloning of this stream requires re-executing the query. */
private class QBEMySQLResultStream: QBESequenceStream {
	init(result: QBEMySQLResult) {
		super.init(SequenceOf<QBETuple>(result), columnNames: result.columnNames)
	}
	
	override func clone() -> QBEStream {
		fatalError("QBEMySQLResultStream cannot be cloned, because a result cannot be iterated multiple times. Clone QBEMySQLStream instead")
	}
}

/** Stream that lazily queries and streams results from a MySQL query.
*/
class QBEMySQLStream: QBEStream {
	private var resultStream: QBEStream?
	private let data: QBEMySQLData
	
	init(data: QBEMySQLData) {
		self.data = data
	}
	
	private func stream() -> QBEStream {
		if resultStream == nil {
			if let rs = data.result() {
				resultStream = QBEMySQLResultStream(result: rs)
			}
			else {
				resultStream = QBEEmptyStream()
			}
		}
		return resultStream!
	}
	
	func fetch(consumer: QBESink, job: QBEJob?) {
		return stream().fetch(consumer, job: job)
	}
	
	func columnNames(callback: ([QBEColumn]) -> ()) {
		return stream().columnNames(callback)
	}
	
	func clone() -> QBEStream {
		return QBEMySQLStream(data: data)
	}
}

class QBEMySQLSourceStep: QBEStep {
	var tableName: String?
	var host: String?
	var user: String?
	var password: String?
	var database: String?
	var port: Int?
	
	init(host: String, port: Int, user: String, password: String, database: String, tableName: String) {
		self.host = host
		self.user = user
		self.password = password
		self.port = port
		self.database = database
		self.tableName = tableName
		super.init(previous: nil)
	}
	
	required init(coder aDecoder: NSCoder) {
		self.tableName = (aDecoder.decodeObjectForKey("tableName") as? String) ?? ""
		self.host = (aDecoder.decodeObjectForKey("host") as? String) ?? ""
		self.database = (aDecoder.decodeObjectForKey("database") as? String) ?? ""
		self.user = (aDecoder.decodeObjectForKey("user") as? String) ?? ""
		self.password = (aDecoder.decodeObjectForKey("password") as? String) ?? ""
		self.port = Int(aDecoder.decodeIntForKey("port"))
		super.init(coder: aDecoder)
	}
	
	override func encodeWithCoder(coder: NSCoder) {
		super.encodeWithCoder(coder)
		coder.encodeObject(tableName, forKey: "tableName")
		coder.encodeObject(host, forKey: "host")
		coder.encodeObject(user, forKey: "user")
		coder.encodeObject(password, forKey: "password")
		coder.encodeObject(database, forKey: "database")
		coder.encodeInt(Int32(port ?? 0), forKey: "port")
	}
	
	override func explain(locale: QBELocale, short: Bool) -> String {
		if short {
			return NSLocalizedString("MySQL table", comment: "")
		}
		return String(format: NSLocalizedString("Load table %@ from MySQL database", comment: ""), self.tableName ?? "")
	}
	
	internal var server: QBEMySQLServer? { get {
		if let h = host, p = port, u = user, pw = password, d = database {
			/* For MySQL, the hostname 'localhost' is special and indicates access through a local UNIX socket. This does
			not work from a sandboxed application unless special privileges are obtained. To avoid confusion we rewrite
			localhost here to 127.0.0.1 in order to force access through TCP/IP. */
			let ha = (h == "localhost") ? "127.0.0.1" : h
			return QBEMySQLServer(host: ha, port: p, user: u, password: pw, database: d)
		}
		return nil
	} }
	
	override func fullData(job: QBEJob?, callback: (QBEData) -> ()) {
		QBEAsyncBackground {
			if let s = self.server {
				callback(QBECoalescedData(QBEMySQLData(server: s, tableName: self.tableName ?? "", locale: QBEAppDelegate.sharedInstance.locale)))
			}
			else {
				callback(QBERasterData())
			}
		}
	}
	
	override func exampleData(job: QBEJob?, maxInputRows: Int, maxOutputRows: Int, callback: (QBEData) -> ()) {
		self.fullData(job, callback: { (fd) -> () in
			callback(fd.random(maxInputRows))
		})
	}
}