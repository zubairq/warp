import Cocoa
import XCTest
@testable import WarpCore

class WarpCoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    } 
	
	func testStatistics() {
		let moving = Moving(size: 10, items: [0,10,0,10,0,10,10,10,0,0,10,0,10,0,10,999999999999,0,5,5,5,5,5,5,5,5,5,5,5])
		XCTAssert(moving.sample.n == 10, "Moving should discard old samples properly")
		XCTAssert(moving.sample.mean == 5.0, "Average of test sample should be exactly 5")
		XCTAssert(moving.sample.stdev == 0.0, "Test sample has no deviations")

		let (lower, upper) = moving.sample.confidenceInterval(0.90)
		XCTAssert(lower <= upper, "Test sample confidence interval must not be flipped")
		XCTAssert(lower == 5.0 && upper == 5.0, "Test sample has confidence interval that is [5,5]")

		// Add a value to the moving average and try again
		moving.add(100)
		XCTAssert(moving.sample.n == 10, "Moving should discard old samples properly")
		XCTAssert(moving.sample.mean > 5.0, "Average of test sample should be > 5")
		XCTAssert(moving.sample.stdev > 0.0, "Test sample has a deviation now")
		let (lower2, upper2) = moving.sample.confidenceInterval(0.90)
		XCTAssert(lower2 <= upper2, "Test sample confidence interval must not be flipped")
		XCTAssert(lower2 < 5.0 && upper2 > 5.0, "Test sample has confidence interval that is wider")

		let (lower3, upper3) = moving.sample.confidenceInterval(0.95)
		XCTAssert(lower3 < lower2 && upper3 > upper2, "A more confident interval is wider")
	}

	func testArithmetic() {
		// Strings
		XCTAssert(Value("hello") == Value("hello"), "String equality")
		XCTAssert(Value("hello") != Value("HELLO"), "String equality is case sensitive")
		XCTAssert(Value(1337) == Value("1337"), "Numbers are strings")
		XCTAssert("Tommy".levenshteinDistance("tommy") == 1, "Levenshtein is case sensitive")
		XCTAssert("Tommy".levenshteinDistance("Tomy") == 1, "Levenshtein recognizes deletes")
		XCTAssert("Tommy".levenshteinDistance("ymmoT") == 4, "Levenshtein recognizes moves")
		XCTAssert("Tommy".levenshteinDistance("TommyV") == 1, "Levenshtein recognizes adds")

		// Booleans
		XCTAssert(true.toDouble()==1.0, "True is double 1.0")
		XCTAssert(false.toDouble()==0.0, "False is double 0.0")
		XCTAssert(true.toInt()==1, "True is integer 1")
		XCTAssert(false.toInt()==0, "False is integer 0")

		// Invalid value
		XCTAssert(Value.InvalidValue != Value.InvalidValue, "Invalid value does not equal itself")
		XCTAssert(Value.InvalidValue != Value.EmptyValue, "Invalid value does not equal empty value")
		XCTAssert(Value.InvalidValue != Value.BoolValue(false), "Invalid value does not equal false value")

		// Empty value
		XCTAssert(Value.EmptyValue == Value.EmptyValue, "Empty equals empty")
		XCTAssert(Value.EmptyValue != Value.StringValue(""), "Empty does not equal empty string")
		XCTAssert(Value.EmptyValue != Value.IntValue(0), "Empty does not equal zero integer")
		XCTAssert(Value.EmptyValue != Value.BoolValue(false), "Empty does not equal false")

		// Numeric operations
		XCTAssert(Value(12) * Value(13) == Value(156), "Integer multiplication")
		XCTAssert(Value(12.2) * Value(13.3) == Value(162.26), "Double multiplication")
		XCTAssert(Value(12) * Value(13) == Value(156), "Integer multiplication to double")
		XCTAssert(Value(12) / Value(2) == Value(6), "Integer division to double")
		XCTAssert(!(Value(10.0) / Value(0)).isValid, "Division by zero")
		XCTAssert(Value(Double(Int.max)+1.0).intValue == nil, "Doubles that are too large to be converted to Int should not be representible as integer value")
		XCTAssert(Value(Double(Int.min)-1.0).intValue == nil, "Doubles that are too large negatively to be converted to Int should not be representible as integer value")

		// String operations
		XCTAssert(Value("1337") & Value("h4x0r") == Value("1337h4x0r"), "String string concatenation")

		// Implicit conversions
		XCTAssert((Value(13) + Value("37")) == Value.IntValue(50), "Integer plus string results in integer")
		XCTAssert(Value("13") + Value(37) == Value.IntValue(50), "String plus integer results in integer")
		XCTAssert(Value("13") + Value("37") == Value.IntValue(50), "String plus integer results in integer")
		XCTAssert(Value(true) + Value(true) == Value.IntValue(2), "True + true == 2")
		XCTAssert(!(Value(1) + Value.EmptyValue).isValid, "1 + Empty is not valid")
		XCTAssert(!(Value.EmptyValue + Value.EmptyValue).isValid, "Empty + Empty is not valud")
		XCTAssert(!(Value(12) + Value.InvalidValue).isValid, "Int + Invalid is not valid")

		XCTAssert((Value(13) - Value("37")) == Value.IntValue(-24), "Integer minus string results in integer")
		XCTAssert(Value("13") - Value(37) == Value.IntValue(-24), "String minus integer results in integer")
		XCTAssert(Value("13") - Value("37") == Value.IntValue(-24), "String minus integer results in integer")
		XCTAssert(Value(true) - Value(true) == Value.IntValue(0), "True + true == 2")
		XCTAssert(!(Value(1) - Value.EmptyValue).isValid, "1 - Empty is not valid")
		XCTAssert(!(Value.EmptyValue - Value.EmptyValue).isValid, "Empty - Empty is  ot valud")
		XCTAssert(!(Value(12) - Value.InvalidValue).isValid, "Int - Invalid is not valid")

		// Numeric comparisons
		XCTAssert((Value(12) < Value(25)) == Value(true), "Less than")
		XCTAssert((Value(12) > Value(25)) == Value(false), "Greater than")
		XCTAssert((Value(12) <= Value(25)) == Value(true), "Less than or equal")
		XCTAssert((Value(12) >= Value(25)) == Value(false), "Greater than or equal")
		XCTAssert((Value(12) <= Value(12)) == Value(true), "Less than or equal")
		XCTAssert((Value(12) >= Value(12)) == Value(true), "Greater than or equal")

		// Equality
		XCTAssert((Value(12.0) == Value(12)) == Value(true), "Double == int")
		XCTAssert((Value(12) == Value(12.0)) == Value(true), "Int == double")
		XCTAssert((Value(12.0) != Value(12)) == Value(false), "Double != int")
		XCTAssert((Value(12) != Value(12.0)) == Value(false), "Int != double")
		XCTAssert(Value("12") == Value(12), "String number is treated as number")
		XCTAssert((Value("12") + Value("13")) == Value(25), "String number is treated as number")
		XCTAssert(Value.EmptyValue == Value.EmptyValue, "Empty equals empty")
		XCTAssert(!(Value.InvalidValue == Value.InvalidValue), "Invalid value equals nothing")

		// Inequality
		XCTAssert(Value.EmptyValue != Value(0), "Empty is not equal to zero")
		XCTAssert(Value.EmptyValue != Value(Double.NaN), "Empty is not equal to double NaN")
		XCTAssert(Value.EmptyValue != Value(""), "Empty is not equal to empty string")
		XCTAssert(Value.InvalidValue != Value.InvalidValue, "Invalid value inequals other invalid value")

		// Packs
		XCTAssert(Pack("a,b,c,d").count == 4, "Pack format parser works")
		XCTAssert(Pack("a,b,c,d,").count == 5, "Pack format parser works")
		XCTAssert(Pack("a,b$0,c$1$0,d$0$1").count == 4, "Pack format parser works")
		XCTAssert(Pack(",").count == 2, "Pack format parser works")
		XCTAssert(Pack("").count == 0, "Pack format parser works")
		XCTAssert(Pack(["Tommy", "van$,der,Vorst"]).stringValue == "Tommy,van$1$0der$0Vorst", "Pack writer properly escapes")
	}

	func testFunctions() {
		for fun in Function.allFunctions {
			switch fun {

			case .Xor:
				XCTAssert(Function.Xor.apply([Value(true), Value(true)]) == Value(false), "XOR(true, true)")
				XCTAssert(Function.Xor.apply([Value(true), Value(false)]) == Value(true), "XOR(true, false)")
				XCTAssert(Function.Xor.apply([Value(false), Value(false)]) == Value(false), "XOR(false, false)")

			case .Identity:
				XCTAssert(Function.Identity.apply([Value(1.337)]) == Value(1.337),"Identity")

			case .Not:
				XCTAssert(Function.Not.apply([Value(false)]) == Value(true), "Not")

			case .And:
				XCTAssert(Function.And.apply([Value(true), Value(true)]) == Value(true), "AND(true, true)")
				XCTAssert(!Function.And.apply([Value(true), Value.InvalidValue]).isValid, "AND(true, invalid)")
				XCTAssert(Function.And.apply([Value(true), Value(false)]) == Value(false), "AND(true, false)")
				XCTAssert(Function.And.apply([Value(false), Value(false)]) == Value(false), "AND(false, false)")

			case .Lowercase:
				XCTAssert(Function.Lowercase.apply([Value("Tommy")]) == Value("tommy"), "Lowercase")

			case .Uppercase:
				XCTAssert(Function.Uppercase.apply([Value("Tommy")]) == Value("TOMMY"), "Uppercase")

			case .Absolute:
				XCTAssert(Function.Absolute.apply([Value(-1)]) == Value(1), "Absolute")

			case .Count:
				XCTAssert(Function.Count.apply([]) == Value(0), "Empty count returns zero")
				XCTAssert(Function.Count.apply([Value(1), Value(1), Value.InvalidValue, Value.EmptyValue]) == Value(2), "Count does not include invalid values and empty values")

			case .Items:
				XCTAssert(Function.Items.apply([Value("")]) == Value(0), "Empty count returns zero")
				XCTAssert(Function.Items.apply([Value("Foo,bar,baz")]) == Value(3), "Count does not include invalid values and empty values")

			case .CountAll:
				XCTAssert(Function.CountAll.apply([Value(1), Value(1), Value.InvalidValue, Value.EmptyValue]) == Value(4), "CountAll includes invalid values and empty values")

			case .Negate:
				XCTAssert(Function.Negate.apply([Value(1337)]) == Value(-1337), "Negate")

			case .Or:
				XCTAssert(Function.Or.apply([Value(true), Value(true)]) == Value(true), "OR(true, true)")
				XCTAssert(Function.Or.apply([Value(true), Value(false)]) == Value(true), "OR(true, false)")
				XCTAssert(Function.Or.apply([Value(false), Value(false)]) == Value(false), "OR(false, false)")
				XCTAssert(!Function.Or.apply([Value(true), Value.InvalidValue]).isValid, "OR(true, invalid)")

			case .Acos:
				XCTAssert(Function.Acos.apply([Value(0.337)]) == Value(acos(0.337)), "Acos")
				XCTAssert(!Function.Acos.apply([Value(1.337)]).isValid, "Acos")

			case .Asin:
				XCTAssert(Function.Asin.apply([Value(0.337)]) == Value(asin(0.337)), "Asin")
				XCTAssert(!Function.Asin.apply([Value(1.337)]).isValid, "Asin")

			case .NormalInverse:
				let ni = Function.NormalInverse.apply([Value(0.25), Value(42), Value(4)])
				XCTAssert(ni > Value(39) && ni < Value(40), "NormalInverse")

			case .Atan:
				XCTAssert(Function.Atan.apply([Value(1.337)]) == Value(atan(1.337)), "Atan")

			case .Cosh:
				XCTAssert(Function.Cosh.apply([Value(1.337)]) == Value(cosh(1.337)), "Cosh")

			case .Sinh:
				XCTAssert(Function.Sinh.apply([Value(1.337)]) == Value(sinh(1.337)), "Sinh")

			case .Tanh:
				XCTAssert(Function.Tanh.apply([Value(1.337)]) == Value(tanh(1.337)), "Tanh")

			case .Cos:
				XCTAssert(Function.Cos.apply([Value(1.337)]) == Value(cos(1.337)), "Cos")

			case .Sin:
				XCTAssert(Function.Sin.apply([Value(1.337)]) == Value(sin(1.337)), "Sin")

			case .Tan:
				XCTAssert(Function.Tan.apply([Value(1.337)]) == Value(tan(1.337)), "Tan")

			case .Sqrt:
				XCTAssert(Function.Sqrt.apply([Value(1.337)]) == Value(sqrt(1.337)), "Sqrt")
				XCTAssert(!Function.Sqrt.apply([Value(-1)]).isValid, "Sqrt")

			case .Round:
				XCTAssert(Function.Round.apply([Value(1.337)]) == Value(1), "Round")
				XCTAssert(Function.Round.apply([Value(1.337), Value(2)]) == Value(1.34), "Round")
				XCTAssert(Function.Round.apply([Value(0.5)]) == Value(1), "Round")

			case .Log:
				XCTAssert(Function.Log.apply([Value(1.337)]) == Value(log10(1.337)), "Log")
				XCTAssert(!Function.Log.apply([Value(0)]).isValid, "Log")

			case .Exp:
				XCTAssert(Function.Exp.apply([Value(1.337)]) == Value(exp(1.337)), "Exp")
				XCTAssert(Function.Exp.apply([Value(0)]) == Value(1), "Exp")

			case .Ln:
				XCTAssert(Function.Ln.apply([Value(1.337)]) == Value(log10(1.337) / log10(exp(1.0))), "Ln")
				XCTAssert(!Function.Ln.apply([Value(0)]).isValid, "Ln")

			case .Concat:
				XCTAssert(Function.Concat.apply([Value(1), Value("33"), Value(false)]) == Value("1330"), "Concat")

			case .If:
				XCTAssert(Function.If.apply([Value(true), Value(13), Value(37)]) == Value(13), "If")
				XCTAssert(Function.If.apply([Value(false), Value(13), Value(37)]) == Value(37), "If")
				XCTAssert(!Function.If.apply([Value.InvalidValue, Value(13), Value(37)]).isValid, "If")

			case .Left:
				XCTAssert(Function.Left.apply([Value(1337), Value(3)]) == Value(133), "Left")
				XCTAssert(!Function.Left.apply([Value(1337), Value(5)]).isValid, "Left")

			case .Right:
				XCTAssert(Function.Right.apply([Value(1337), Value(3)]) == Value(337), "Right")
				XCTAssert(!Function.Right.apply([Value(1337), Value(5)]).isValid, "Right")

			case .Mid:
				XCTAssert(Function.Mid.apply([Value(1337), Value(3), Value(1)]) == Value(7), "Mid")
				XCTAssert(Function.Mid.apply([Value(1337), Value(3), Value(10)]) == Value(7), "Mid")

			case .Substitute:
				XCTAssert(Function.Substitute.apply([Value("foobar"), Value("foo"), Value("bar")]) == Value("barbar"), "Substitute")

			case .Length:
				XCTAssert(Function.Length.apply([Value("test")]) == Value(4), "Length")

			case .Sum:
				XCTAssert(Function.Sum.apply([1,3,3,7].map({return Value($0)})) == Value(1+3+3+7), "Sum")
				XCTAssert(Function.Sum.apply([]) == Value(0), "Sum")

			case .Min:
				XCTAssert(Function.Min.apply([1,3,3,7].map({return Value($0)})) == Value(1), "Min")
				XCTAssert(!Function.Min.apply([]).isValid, "Min")

			case .Max:
				XCTAssert(Function.Max.apply([1,3,3,7].map({return Value($0)})) == Value(7), "Max")
				XCTAssert(!Function.Max.apply([]).isValid, "Max")

			case .Average:
				XCTAssert(Function.Average.apply([1,3,3,7].map({return Value($0)})) == Value((1.0+3.0+3.0+7.0)/4.0), "Average")
				XCTAssert(!Function.Average.apply([]).isValid, "Average")

			case .Trim:
				XCTAssert(Function.Trim.apply([Value("   trim  ")]) == Value("trim"), "Trim")
				XCTAssert(Function.Trim.apply([Value("  ")]) == Value(""), "Trim")

			case .Choose:
				XCTAssert(Function.Choose.apply([3,3,3,7].map({return Value($0)})) == Value(7), "Choose")
				XCTAssert(!Function.Choose.apply([Value(3)]).isValid, "Choose")

			case .Random:
				let rv = Function.Random.apply([])
				XCTAssert(rv >= Value(0.0) && rv <= Value(1.0), "Random")

			case .RandomBetween:
				let rv = Function.RandomBetween.apply([Value(-10), Value(9)])
				XCTAssert(rv >= Value(-10.0) && rv <= Value(9.0), "RandomBetween")

			case .RandomItem:
				let items = [1,3,3,7].map({return Value($0)})
				XCTAssert(items.contains(Function.RandomItem.apply(items)), "RandomItem")

			case .Pack:
				XCTAssert(Function.Pack.apply([Value("He,llo"),Value("World")]) == Value(Pack(["He,llo", "World"]).stringValue), "Pack")

			case .Split:
				XCTAssert(Function.Split.apply([Value("Hello#World"), Value("#")]) == Value("Hello,World"), "Split")

			case .Nth:
				XCTAssert(Function.Nth.apply([Value("Foo,bar,baz"), Value(3)]) == Value("baz"), "Nth")

			case .Sign:
				XCTAssert(Function.Sign.apply([Value(-1337)]) == Value(-1), "Sign")
				XCTAssert(Function.Sign.apply([Value(0)]) == Value(0), "Sign")
				XCTAssert(Function.Sign.apply([Value(1337)]) == Value(1), "Sign")

			case .IfError:
				XCTAssert(Function.IfError.apply([Value.InvalidValue, Value(1337)]) == Value(1337), "IfError")
				XCTAssert(Function.IfError.apply([Value(1336), Value(1337)]) == Value(1336), "IfError")

			case .Levenshtein:
				XCTAssert(Function.Levenshtein.apply([Value("tommy"), Value("tom")]) == Value(2), "Levenshtein")

			case .RegexSubstitute:
				XCTAssert(Function.RegexSubstitute.apply([Value("Tommy"), Value("m+"), Value("@")]) == Value("To@y"), "RegexSubstitute")

			case .Coalesce:
				XCTAssert(Function.Coalesce.apply([Value.InvalidValue, Value.InvalidValue, Value(1337)]) == Value(1337), "Coalesce")

			case .Capitalize:
				XCTAssert(Function.Capitalize.apply([Value("tommy van DER vorst")]) == Value("Tommy Van Der Vorst"), "Capitalize")

			case .URLEncode:
				// FIXME: URLEncode should probably also encode slashes, right?
				XCTAssert(Function.URLEncode.apply([Value("tommy%/van DER vorst")]) == Value("tommy%25/van%20DER%20vorst"), "URLEncode")

			case .In:
				XCTAssert(Function.In.apply([Value(1), Value(1), Value(2)]) == Value.BoolValue(true), "In")
				XCTAssert(Function.In.apply([Value(1), Value(3), Value(2)]) == Value.BoolValue(false), "In")

			case .NotIn:
				XCTAssert(Function.NotIn.apply([Value(1), Value(2), Value(2)]) == Value.BoolValue(true), "NotIn")
				XCTAssert(Function.NotIn.apply([Value(1), Value(1), Value(2)]) == Value.BoolValue(false), "NotIn")

			case .ToUnixTime:
				let d = NSDate()
				XCTAssert(Function.ToUnixTime.apply([Value(d)]) == Value(d.timeIntervalSince1970), "ToUnixTime")
				let epoch = NSDate(timeIntervalSince1970: 0)
				XCTAssert(Function.ToUnixTime.apply([Value(epoch)]) == Value(0), "ToUnixTime")

			case .FromUnixTime:
				XCTAssert(Function.FromUnixTime.apply([Value(0)]) == Value(NSDate(timeIntervalSince1970: 0)), "FromUnixTime")

			case .Now:
				break

			case .FromISO8601:
				XCTAssert(Function.FromISO8601.apply([Value("1970-01-01T00:00:00Z")]) == Value(NSDate(timeIntervalSince1970: 0)), "FromISO8601")

			case .ToLocalISO8601:
				break

			case .ToUTCISO8601:
				XCTAssert(Function.ToUTCISO8601.apply([Value(NSDate(timeIntervalSince1970: 0))]) == Value("1970-01-01T00:00:00Z"), "ToUTCISO8601")

			case .FromExcelDate:
				XCTAssert(Function.FromExcelDate.apply([Value(25569.0)]) == Value(NSDate(timeIntervalSince1970: 0.0)), "FromExcelDate")
				XCTAssert(Function.FromExcelDate.apply([Value(42210.8330092593)]) == Value(NSDate(timeIntervalSinceReferenceDate: 459547172.0)), "FromExcelDate")

			case .ToExcelDate:
				XCTAssert(Function.ToExcelDate.apply([Value(NSDate(timeIntervalSince1970: 0.0))]) == Value(25569.0), "ToExcelDate")
				XCTAssert(Function.ToExcelDate.apply([Value(NSDate(timeIntervalSinceReferenceDate: 459547172))]).doubleValue!.approximates(42210.8330092593, epsilon: 0.01), "ToExcelDate")

			case .UTCDate:
				XCTAssert(Function.UTCDate.apply([Value(2001), Value(1), Value(1)]) == Value.DateValue(0.0), "UTCDate")

			case .UTCYear:
				XCTAssert(Function.UTCYear.apply([Value.DateValue(0)]) == Value(2001), "UTCYear")

			case .UTCMonth:
				XCTAssert(Function.UTCMonth.apply([Value.DateValue(0)]) == Value(1), "UTCMonth")

			case .UTCDay:
				XCTAssert(Function.UTCDay.apply([Value.DateValue(0)]) == Value(1), "UTCDay")

			case .UTCHour:
				XCTAssert(Function.UTCHour.apply([Value.DateValue(0)]) == Value(0), "UTCHour")

			case .UTCMinute:
				XCTAssert(Function.UTCMinute.apply([Value.DateValue(0)]) == Value(0), "UTCMinute")

			case .UTCSecond:
				XCTAssert(Function.UTCSecond.apply([Value.DateValue(0)]) == Value(0), "UTCSecond")

			case .Duration:
				let start = Value(NSDate(timeIntervalSinceReferenceDate: 1337.0))
				let end = Value(NSDate(timeIntervalSinceReferenceDate: 1346.0))
				XCTAssert(Function.Duration.apply([start, end]) == Value(9.0), "Duration")
				XCTAssert(Function.Duration.apply([end, start]) == Value(-9.0), "Duration")

			case .After:
				let start = Value(NSDate(timeIntervalSinceReferenceDate: 1337.0))
				let end = Value(NSDate(timeIntervalSinceReferenceDate: 1346.0))
				XCTAssert(Function.After.apply([start, Value(9.0)]) == end, "After")
				XCTAssert(Function.After.apply([end, Value(-9.0)]) == start, "After")

			case .Ceiling:
				XCTAssert(Function.Ceiling.apply([Value(1.337)]) == Value(2), "Ceiling")

			case .Floor:
				XCTAssert(Function.Floor.apply([Value(1.337)]) == Value(1), "Floor")

			case .RandomString:
				XCTAssert(Function.RandomString.apply([Value("[0-9]")]).stringValue!.characters.count == 1, "RandomString")

			case .ToUnicodeDateString:
				XCTAssert(Function.ToUnicodeDateString.apply([Value.DateValue(460226561.0), Value("yyy-MM-dd")]) == Value("2015-08-02"), "ToUnicodeDateString")

			case .FromUnicodeDateString:
				XCTAssert(Function.FromUnicodeDateString.apply([Value("1988-08-11"), Value("yyyy-MM-dd")]) == Value(NSDate.fromISO8601FormattedDate("1988-08-11T00:00:00Z")!), "FromUnicodeDateString")

			case .Power:
				XCTAssert(Function.Power.apply([Value(2), Value(0)]) == Value(1), "Power")
			}
		}

		// Binaries
		XCTAssert(Binary.ContainsString.apply(Value("Tommy"), Value("om"))==Value(true), "Contains string operator should be case-insensitive")
		XCTAssert(Binary.ContainsString.apply(Value("Tommy"), Value("x"))==Value(false), "Contains string operator should work")
		XCTAssert(Binary.ContainsStringStrict.apply(Value("Tommy"), Value("Tom"))==Value(true), "Strict contains string operator should work")
		XCTAssert(Binary.ContainsStringStrict.apply(Value("Tommy"), Value("tom"))==Value(false), "Strict contains string operator should be case-sensitive")
		XCTAssert(Binary.ContainsStringStrict.apply(Value("Tommy"), Value("x"))==Value(false), "Strict contains string operator should work")

		// Split / nth
		XCTAssert(Function.Split.apply([Value("van der Vorst, Tommy"), Value(" ")]).stringValue == "van,der,Vorst$0,Tommy", "Split works")
		XCTAssert(Function.Nth.apply([Value("van,der,Vorst$0,Tommy"), Value(3)]).stringValue == "Vorst,", "Nth works")
		XCTAssert(Function.Items.apply([Value("van,der,Vorst$0,Tommy")]).intValue == 4, "Items works")
		
		// Stats
		let z = Function.NormalInverse.apply([Value(0.9), Value(10), Value(5)]).doubleValue
		XCTAssert(z != nil, "NormalInverse should return a value under normal conditions")
		XCTAssert(z! > 16.406 && z! < 16.408, "NormalInverse should results that are equal to those of NORM.INV.N in Excel")
	}
	
	func testEmptyRaster() {
		let emptyRaster = Raster()
		XCTAssert(emptyRaster.rowCount == 0, "Empty raster is empty")
		XCTAssert(emptyRaster.columnCount == 0, "Empty raster is empty")
		XCTAssert(emptyRaster.columnNames.count == emptyRaster.columnCount, "Column count matches")
	}
	
	func testColumn() {
		XCTAssert(Column("Hello") == Column("hello"), "Case-insensitive column names")
		XCTAssert(Column("xxx") != Column("hello"), "Case-insensitive column names")
		
		XCTAssert(Column.defaultColumnForIndex(1337)==Column("BZL"), "Generation of column names")
		XCTAssert(Column.defaultColumnForIndex(0)==Column("A"), "Generation of column names")
		XCTAssert(Column.defaultColumnForIndex(1)==Column("B"), "Generation of column names")
	}
	
	func testSequencer() {
		func checkSequence(formula: String, _ expected: [String]) {
			let expectedValues = Set(expected.map { return Value($0) })
			let sequencer = Sequencer(formula)!
			let result = Set(Array(sequencer.root!))
			XCTAssert(result.count == sequencer.cardinality, "Expected number of items matches with the actual number of items for sequence \(formula)")
			XCTAssert(result.isSupersetOf(expectedValues) && expectedValues.isSupersetOf(result), "Sequence \(formula) returns \(expectedValues), got \(result)")
		}

		checkSequence("[AB]{2}", ["AA","AB","BA","BB"])
		checkSequence("test", ["test"])
		checkSequence("(foo)bar", ["foobar"])
		checkSequence("foo?bar", ["bar", "foobar"])
		checkSequence("[abc][\\[]", ["a[", "b[", "c["])
		checkSequence("[1-4]", ["1", "2", "3", "4"])
		checkSequence("[abc]", ["a", "b", "c"])
		checkSequence("[abc][def]", ["ad", "ae", "af", "bd", "be", "bf", "cd", "ce", "cf"])
		checkSequence("[abc]|[def]", ["a","b","c","d","e","f"])
		checkSequence("[A-E]{2}", ["AA","AB","AC","AD","AE","BA","BB","BC","BD","BE","CA","CB","CC","CD","CE","DA","DB","DC","DD","DE","EA","EB","EC","ED","EE"])
		
		XCTAssert(Sequencer("'") == nil, "Do not parse everything")
		XCTAssert(Array(Sequencer("[A-C]{2}")!.root!).count == 3*3, "Sequence [A-C]{2} delivers 3*3 items")
		XCTAssert(Array(Sequencer("[A-Z]{2}")!.root!).count == 26*26, "Sequence [A-Z]{2} delivers 26*26 items")
		XCTAssert(Array(Sequencer("[A-Z][a-z]")!.root!).count == 26*26, "Sequence <A-Z><a-z> should generate 26*26 items")
		XCTAssert(Array(Sequencer("[abc]|[def]")!.root!).count == 6, "Sequence [abc]|[def] should generate 6 items")
		XCTAssert(Array(Sequencer("([abc]|[def])")!.root!).count == 6, "Sequence ([abc]|[def]) should generate 6 items")
		XCTAssert(Array(Sequencer("([abc]|[def])[xyz]")!.root!).count == 6 * 3, "Sequence ([abc]|[def])[xyz] should generate 6*3 items")
		
		XCTAssert(Sequencer("([0-9]{2}\\-[A-Z]{3}\\-[0-9])|([A-Z]{2}\\-[A-Z]{2}\\-[0-9]{2})")!.cardinality == 63273600,"Cardinality of a complicated sequencer expression is correct")

		// [a-z]{40} generates 4^40 items, which is much larger than Int.max, so cardinality cannot be reported.
		XCTAssert(Sequencer("[a-z]{40}")!.cardinality == nil, "Very large sequences should not have cardinality defined")
	}
	
	func testFormulaParser() {
		let locale = Locale(language: Locale.defaultLanguage)
		
		// Test whether parsing goes right
		XCTAssert(Formula(formula: "1.337", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(1.337), "Parse decimal numbers")
		XCTAssert(Formula(formula: "1,337,338", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(1337338), "Parse numbers with thousand separators")
		XCTAssert(Formula(formula: "1337,338", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(1337338), "Parse numbers with thousand separators in the wrong place")
		XCTAssert(Formula(formula: "1.337.338", locale: locale)==nil, "Parse numbers with double decimal separators should fail")
		XCTAssert(Formula(formula: "13%", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(0.13), "Parse percentages")
		XCTAssert(Formula(formula: "10Ki", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(10 * 1024), "Parse SI postfixes")

		XCTAssert(Formula(formula: "6/ 2", locale: locale) != nil, "Parse whitespace around binary operator: right side")
		XCTAssert(Formula(formula: "6 / 2", locale: locale) != nil, "Parse whitespace around binary operator: both sides")
		XCTAssert(Formula(formula: "6 /2", locale: locale) != nil, "Parse whitespace around binary operator: left side")
		XCTAssert(Formula(formula: "(6>=2)>3", locale: locale) != nil, "Parse greater than or equals, while at the same time parsing greater than")
		
		XCTAssert(Formula(formula: "6/(1-3/4)", locale: locale) != nil, "Formula in default dialect")
		XCTAssert(Formula(formula: "6/(1-3/4)±", locale: locale) == nil, "Formula needs to ignore any garbage near the end of a formula")
		XCTAssert(Formula(formula: "6/(1-3/4)+[@colRef]", locale: locale) != nil, "Formula in default dialect with column ref")
		XCTAssert(Formula(formula: "6/(1-3/4)+[#colRef]", locale: locale) != nil, "Formula in default dialect with foreign ref")
		XCTAssert(Formula(formula: "6/(1-3/4)+[@colRef]&\"stringLit\"", locale: locale) != nil, "Formula in default dialect with string literal")
		
		for ws in [" ","\t", " \t", "\r", "\n", "\r\n"] {
			XCTAssert(Formula(formula: "6\(ws)/\(ws)(\(ws)1-3/\(ws)4)", locale: locale) != nil, "Formula with whitespace '\(ws)' in between")
			XCTAssert(Formula(formula: "\(ws)6\(ws)/\(ws)(\(ws)1-3/\(ws)4)", locale: locale) != nil, "Formula with whitespace '\(ws)' at beginning")
			XCTAssert(Formula(formula: "6\(ws)/\(ws)(\(ws)1-3/\(ws)4)\(ws)", locale: locale) != nil, "Formula with whitespace '\(ws)' at end")
		}
		
		// Test results
		XCTAssert(Formula(formula: "6/(1-3/4)", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(24), "Formula in default dialect")
		
		// Test whether parsing goes wrong when it should
		XCTAssert(Formula(formula: "", locale: locale) == nil, "Empty formula")
		XCTAssert(Formula(formula: "1+22@D@D@", locale: locale) == nil, "Garbage formula")
		

		XCTAssert(Formula(formula: "fALse", locale: locale) != nil, "Constant names should be case-insensitive")
		XCTAssert(Formula(formula: "siN(1)", locale: locale) != nil, "Function names should be case-insensitive")
		XCTAssert(Formula(formula: "SIN(1)", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(sin(1.0)), "SIN(1)=sin(1)")
		XCTAssert(Formula(formula: "siN(1)", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(sin(1.0)), "siN(1)=sin(1)")
		XCTAssert(Formula(formula: "POWER(1;)", locale: locale) == nil, "Empty arguments are invalid")
		XCTAssert(Formula(formula: "POWER(2;4)", locale: locale)!.root.apply(Row(), foreign: nil, inputValue: nil) == Value(pow(2,4)), "POWER(2;4)==2^4")
	}
	
	func testExpressions() {
		XCTAssert(Literal(Value(13.46)).isConstant, "Literal expression should be constant")
		XCTAssert(!Call(arguments: [], type: Function.RandomItem).isConstant, "Non-deterministic function expression should not be constant")
		
		XCTAssert(!Comparison(first: Literal(Value(13.45)), second: Call(arguments: [], type: Function.RandomItem), type: Binary.Equal).isConstant, "Binary operator applied to at least one non-constant expression should not be constant itself")
		
		
		let locale = Locale(language: Locale.defaultLanguage)
		
		let a = Formula(formula: "([@x]+1)>([@x]+1)", locale: locale)!.root.prepare()
		XCTAssert(a is Literal && a.apply(Row(), foreign: nil, inputValue: nil) == Value.BoolValue(false), "Equivalence is optimized away for '>' operator in x+1 > x+1")
		
		let b = Formula(formula: "(1+[@x])>([@x]+1)", locale: locale)!.root.prepare()
		XCTAssert(b is Literal && b.apply(Row(), foreign: nil, inputValue: nil) == Value.BoolValue(false), "Equivalence is optimized away for '>' operator in x+1 > 1+x")
		
		let c = Formula(formula: "(1+[@x])>=([@x]+1)", locale: locale)!.root.prepare()
		XCTAssert(c is Literal && c.apply(Row(), foreign: nil, inputValue: nil) == Value.BoolValue(true), "Equivalence is optimized away for '>=' operator in x+1 > 1+x")
		
		let d = Formula(formula: "(1+[@x])<>([@x]+1)", locale: locale)!.root.prepare()
		XCTAssert(d is Literal && d.apply(Row(), foreign: nil, inputValue: nil) == Value.BoolValue(false), "Equivalence is optimized away for '<>' operator in x+1 > x+2")
		
		let f = Formula(formula: "(1+[@x])<>([@x]+2)", locale: locale)!.root.prepare()
		XCTAssert(f is Comparison, "Equivalence is NOT optimized away for '<>' operator in x+1 > x+2")
		
		// Optimizer is not smart enough to do the following
		//let e = Formula(formula: "(1+2+[@x])>(2+[@x]+1)", locale: locale)!.root.prepare()
		//XCTAssert(e is Literal && e.apply(Row(), foreign: nil, inputValue: nil) == Value.BoolValue(false), "Equivalence is optimized away for '>' operator in 1+2+x > 2+x+1")
	}
	
	func compareData(job: Job, _ a: Data, _ b: Data, callback: (Bool) -> ()) {
		a.raster(job, callback: { (aRasterFallible) -> () in
			switch aRasterFallible {
				case .Success(let aRaster):
					b.raster(job, callback: { (bRasterFallible) -> () in
						switch bRasterFallible {
							case .Success(let bRaster):
								let equal = aRaster.compare(bRaster)
								if !equal {
									job.log("A: \(aRaster.debugDescription)")
									job.log("B: \(bRaster.debugDescription)")
								}
								callback(equal)
							
							case .Failure(let error):
								XCTFail(error)
						}
					})
				
				case .Failure(let error):
					XCTFail(error)
			}
		})
	}
	
	func testCoalescer() {
		let raster = Raster(data: [
			[Value.IntValue(1), Value.IntValue(2), Value.IntValue(3)],
			[Value.IntValue(4), Value.IntValue(5), Value.IntValue(6)],
			[Value.IntValue(7), Value.IntValue(8), Value.IntValue(9)]
		], columnNames: [Column("a"), Column("b"), Column("c")], readOnly: true)
		
		let inData = RasterData(raster: raster)
		let inOptData = inData.coalesced
		let job = Job(.UserInitiated)

		inData.filter(Literal(Value(false))).raster(job) { rf in
			switch rf {
			case .Success(let r):
				XCTAssert(r.columnNames.count > 0, "Data set that is filtered to be empty should still contains column names")

			case .Failure(let e):
				XCTFail(e)
			}

		}
		
		compareData(job, inData.limit(2).limit(1), inOptData.limit(2).limit(1)) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for limit(2).limit(1) should equal normal result")
		}
		
		compareData(job, inData.offset(2).offset(1), inOptData.offset(2).offset(1)) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for offset(2).offset(1) should equal normal result")
		}
		
		compareData(job, inData.offset(3), inOptData.offset(2).offset(1)) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for offset(2).offset(1) should equal offset(3)")
		}
		
		// Verify coalesced sort operations
		let aSorts = [
			Order(expression: Sibling(columnName: "a"), ascending: true, numeric: true),
			Order(expression: Sibling(columnName: "b"), ascending: false, numeric: true)
		]
		
		let bSorts = [
			Order(expression: Sibling(columnName: "c"), ascending: true, numeric: true)
		]
		
		compareData(job, inData.sort(aSorts).sort(bSorts), inData.sort(bSorts + aSorts)) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for sort().sort() should equal normal result")
		}
		
		compareData(job, inData.sort(aSorts).sort(bSorts), inOptData.sort(aSorts).sort(bSorts)) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for sort().sort() should equal normal result")
		}
		
		// Verify coalesced transpose
		compareData(job, inData.transpose().transpose(), inOptData.transpose().transpose()) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for transpose().transpose() should equal normal result")
		}
		
		compareData(job, inData.transpose().transpose().transpose(), inOptData.transpose().transpose().transpose()) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for transpose().transpose().transpose() should equal normal result")
		}
		
		compareData(job, inData, inOptData.transpose().transpose()) { (equal) -> () in
			XCTAssert(equal, "Coalescer result for transpose().transpose() should equal original result")
		}

		let seqData = StreamData(source: Sequencer("[a-z]{4}")!.stream("Value"))
		seqData.random(1).random(1).raster(job) { rf in
			switch rf {
			case .Success(let r):
				XCTAssert(r.rowCount == 1, "Random.Random returns the wrong row count")

			case .Failure(let e): XCTFail(e)
			}
		}
	}
	
	func testInferer() {
		let locale = Locale(language: Locale.defaultLanguage)
		var suggestions: [Expression] = []
		let cols = ["A","B","C","D"].map({Column($0)})
		let row = [1,3,4,6].map({Value($0)})
		Expression.infer(nil, toValue: Value(24), suggestions: &suggestions, level: 10, row: Row(row, columnNames: cols), column: 0, maxComplexity: Int.max, previousValues: [])
		suggestions.forEach { trace($0.explain(locale)) }
		XCTAssert(suggestions.count>0, "Can solve the 1-3-4-6 24 game.")
	}
	
	func testDataImplementations() {
		let job = Job(.UserInitiated)
		
		var d: [[Value]] = []
		for i in 0..<1000 {
			d.append([Value(i), Value(i+1), Value(i+2)])
		}
		
		func assertRaster(raster: Fallible<Raster>, message: String, condition: (Raster) -> Bool) {
			switch raster {
				case .Success(let r):
					XCTAssertTrue(condition(r), message)
				
				case .Failure(let error):
					XCTFail("\(message) failed: \(error)")
			}
		}
		
		let data = RasterData(data: d, columnNames: [Column("X"), Column("Y"), Column("Z")])
		
		// Limit
		data.limit(5).raster(job) { assertRaster($0, message: "Limit actually works") { $0.rowCount == 5 } }
		
		// Offset
		data.offset(5).raster(job) { assertRaster($0, message: "Offset actually works", condition: { $0.rowCount == 1000 - 5 }) }
		
		// Distinct
		data.distinct().raster(job) {
			assertRaster($0, message: "Distinct removes no columns", condition: { $0.columnCount == 3 })
			assertRaster($0, message: "Distinct removes no rows when they are all unique", condition: { $0.rowCount == 1000 })
		}
		
		// Union
		let secondData = RasterData(data: d, columnNames: [Column("X"), Column("B"), Column("C")])
		data.union(secondData).raster(job) {
			assertRaster($0, message: "Union creates the proper number of columns", condition: { $0.columnCount == 5 })
			assertRaster($0, message: "Union creates the proper number of rows", condition: { $0.rowCount == 2000 })
		}
		data.union(data).raster(job) {
			assertRaster($0, message: "Union creates the proper number of columns in self-union scenario", condition: { $0.columnCount == 3 })
			assertRaster($0, message: "Union creates the proper number of rows in self-union scenario", condition: { $0.rowCount == 2000 })
		}
		
		// Join
		data.join(Join(type: .LeftJoin, foreignData: secondData, expression: Comparison(first: Sibling(columnName: "X"), second: Foreign(columnName: "X"), type: .Equal))).raster(job) {
			assertRaster($0, message: "Join returns the appropriate number of rows in a one-to-one scenario", condition: { (x) in
				x.rowCount == 1000
			})
			assertRaster($0, message: "Join returns the appropriate number of columns", condition: { $0.columnCount == 5 })
		}
		data.join(Join(type: .LeftJoin, foreignData: data, expression: Comparison(first: Sibling(columnName: "X"), second: Foreign(columnName: "X"), type: .Equal))).raster(job) {
			assertRaster($0, message: "Join returns the appropriate number of rows in a self-join one-to-one scenario", condition: { $0.rowCount == 1000 })
			assertRaster($0, message: "Join returns the appropriate number of columns in a self-join", condition: { $0.columnCount == 3 })
		}
		
		// Select columns
		data.selectColumns(["THIS_DOESNT_EXIST"]).columnNames(job) { (r) -> () in
			switch r {
				case .Success(let cns):
					XCTAssert(cns.isEmpty, "Selecting an invalid column returns a set without columns")
				
				case .Failure(let error):
					XCTFail(error)
			}
		}
		
		// Transpose (repeatedly transpose and see if we end up with the initial value)
		data.raster(job) { (r) -> () in
			switch r {
				case .Success(let raster):
					let rowsBefore = raster.rowCount
					let columnsBefore = raster.columnCount
					
					self.measureBlock {
						var td: Data = data
						for _ in 1...11 {
							td = td.transpose()
						}
						
						td.raster(job) { assertRaster($0, message: "Row count matches") { $0.rowCount == columnsBefore - 1 } }
						td.raster(job) { assertRaster($0, message: "Column count matches") { $0.columnCount == rowsBefore + 1 } }
					}
			
				case .Failure(let error):
					XCTFail(error)
			}
			
		}
		
		// Empty raster behavior
		let emptyRasterData = RasterData(data: [], columnNames: [])
		emptyRasterData.limit(5).raster(job) { assertRaster($0, message: "Limit works when number of rows > available rows") { $0.rowCount == 0 } }
		emptyRasterData.selectColumns([Column("THIS_DOESNT_EXIST")]).raster(job) { assertRaster($0, message: "Selecting an invalid column works properly in empty raster") { $0.columnNames.isEmpty } }
	}
	
    func testRaster() {
		let job = Job(.UserInitiated)
		
		var d: [[Value]] = []
		for i in 0...1000 {
			d.append([Value(i), Value(i+1), Value(i+2)])
		}
		
		let rasterData = RasterData(data: d, columnNames: [Column("X"), Column("Y"), Column("Z")])
		rasterData.raster(job) { (raster) -> () in
			switch raster {
				case .Success(let r):
					XCTAssert(r.indexOfColumnWithName("X")==0, "First column has index 0")
					XCTAssert(r.indexOfColumnWithName("x")==0, "Column names should be case-insensitive")
					XCTAssert(r.rowCount == 1001, "Row count matches")
					XCTAssert(r.columnCount == 3, "Column count matches")
				
				case .Failure(let error):
					XCTFail(error)
			}
		}

		// Raster modifications
		let cols = [Column("X"), Column("Y"), Column("Z")]
		let testRaster = Raster(data: d, columnNames: cols)
		XCTAssert(testRaster.rowCount == d.count, "Row count matches")
		testRaster.addRows([[Value.EmptyValue, Value.EmptyValue, Value.EmptyValue]])
		XCTAssert(testRaster.rowCount == d.count+1, "Row count matches after insert")

		testRaster.addColumns([Column("W")])
		XCTAssert(testRaster.columnCount == 3+1, "Column count matches after insert")

		// Raster modifications through RasterMutableData
		let mutableRaster = RasterMutableData(raster: testRaster)
		mutableRaster.performMutation(.Alter(DataDefinition(columnNames: cols)), job: job) { result in
			switch result {
			case .Success:
				XCTAssert(testRaster.columnCount == 3, "Column count matches again after mutation")

				mutableRaster.performMutation(.Truncate, job: job) { result in
					switch result {
					case .Success:
						XCTAssert(testRaster.columnCount == 3, "Column count matches again after mutation")
						XCTAssert(testRaster.rowCount == 0, "Row count matches again after mutation")

					case .Failure(let e): XCTFail(e)
					}
				}

			case .Failure(let e): XCTFail(e)
			}
		}
    }

	func testNormalDistribution() {
		XCTAssert(NormalDistribution().inverse(0.0).isInfinite)
		XCTAssert(NormalDistribution().inverse(1.0).isInfinite)
		XCTAssertEqualWithAccuracy(NormalDistribution().inverse(0.5), 0.0, accuracy: 0.001)
		XCTAssertEqualWithAccuracy(NormalDistribution().inverse(0.25), -0.674490, accuracy: 0.001)
		XCTAssertEqualWithAccuracy(NormalDistribution().inverse(0.75), 0.674490, accuracy: 0.001)
	}
	
	func testThreading() {
		let data = Array<Int>(0...5000000)
		let expectFinish = self.expectationWithDescription("Parallel map finishes in time")
		
		let future = data.parallel(
			map: { (slice: Array<Int>) -> [Int] in
				//println("Worker \(slice)")
				return Array(slice.map({return $0 * 2}))
			},
			reduce: {(s, var r: Int?) -> (Int) in
				for number in s {
					r = (r == nil || number > r) ? number : r
				}
				return r ?? 0
			}
		)
		
		future.get {(result) in
			XCTAssert(result != nil && result! == 10000000, "Parallel M/R delivers the correct result")
			expectFinish.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(15.0, handler: { (err) -> Void in
			if let e = err {
				print("Error=\(e)")
			}
		})
	}
}