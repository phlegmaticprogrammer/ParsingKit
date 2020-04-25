import XCTest
import ParsingKit
import FirstOrderDeepEmbedding

final class ParsingKitTests: XCTestCase {

    func testSymbol() {
        let s = IndexedSymbolName("S")
        let s0 = IndexedSymbolName("S", 0)
        let s1 = IndexedSymbolName("S", 1)
        let t = IndexedSymbolName("T")
        XCTAssertFalse(s.hasIndex)
        XCTAssertFalse(s0.hasIndex)
        XCTAssert(s1.hasIndex)
        XCTAssertEqual(s, s0)
        XCTAssertNotEqual(s, s1)
        XCTAssertNotEqual(s, t)
        XCTAssertEqual("\(s)", "S")
        XCTAssertEqual("\(s0)", "S")
        XCTAssertEqual("\(s1)", "S[1]")
    }
    
    func testUTF8CharLexer() {
        let scalars: [UInt8] = [
            0xF0, 0x9F, 0x91, 0xA8, // man
            0xE2, 0x80, 0x8D, // zero width joiner
            0xF0, 0x9F, 0x91, 0xA9, // woman
            0xF0, 0x9F, 0x91, 0xA7, // girl
            0xF0, 0x9F, 0x91, 0xA6, // boy
            32, 64, 0xD8, 0x00, // invalid!
        ]
        //let s = ArrayInput("ᄀᄀᄀ각ᆨᆨABC")
        let s = ArrayInput(scalars)
        var indices = [Int]()
        var position = 0
        repeat {
            guard let result = UTF8CharLexer().lex(input: s, position: position, in: UNIT.singleton) else { break }
            indices.append(result.length)
            position += result.length
        } while true
        XCTAssertEqual(indices, [11, 4, 4, 1, 1])
    }
    
    func testCalculator() {
        
        func run(_ input : String, ambiguous : Bool, _ results : Int...) {
            let calculator = Calculator(ambiguous: ambiguous)
            let lexers = Lexers<Character>()
            lexers.add(lexer: CharLexer(), for: calculator.Char)
            let parser = Parser(grammar: calculator, lexers: lexers)
            let parseResult = parser.parse(input: ArrayInput(input), position: 0, symbol: calculator.Expr, param: UNIT.singleton)
            switch parseResult {
            case .failed: XCTAssert(results.isEmpty)
            case let .success(length: length, results: parseResults):
                XCTAssertEqual(length, input.count)
                XCTAssertEqual(Set(parseResults.keys), Set(results))
            }
        }
        
        run("512+6*3", ambiguous: false, 530)
        run("6*3+512", ambiguous: false, 530)
        run("512+6*3", ambiguous: true, 530, 80)
        run("10", ambiguous: false, 10)
        run("10", ambiguous: true, 10)
        run("100", ambiguous: false, 100)
        run("100", ambiguous: true, 100, 10)
        run("1000", ambiguous: false, 1000)
        run("1000", ambiguous: true, 1000, 100, 10)
        run("10000", ambiguous: false, 10000)
        run("10000", ambiguous: true, 10000, 1000, 100, 10)
        run("12345", ambiguous: false, 12345)
        
        run("123", ambiguous: true, 123, 33)
        run("234", ambiguous: true, 234, 54)
        run("345", ambiguous: true, 345, 75)

        run("123*10+4", ambiguous: true, 1234, 334)
        run("1*10+234", ambiguous: true, 244, 64)
        run("12*10+34", ambiguous: true, 154)
        run("1234", ambiguous: true, 1234, 334, 244, 64, 154)
        
        run("234*10+5", ambiguous: true, 2345, 545)
        run("2*10+345", ambiguous: true, 365, 95)
        run("23*10+45", ambiguous: true, 275)
        run("2345", ambiguous: true, 2345, 545, 365, 95, 275)
        
        run("1*10+2345", ambiguous: true, 2355, 555, 375, 105, 285)
        run("12*10+345", ambiguous: true, 465, 195)
        run("123*10+45", ambiguous: true, 1275, 375)
        run("1234*10+5", ambiguous: true, 12345, 3345, 2445, 645, 1545)

        run("12345", ambiguous: false, 12345)
        run("12345", ambiguous: true, 2355, 555, 375, 105, 285, 465, 195, 1275, 12345, 3345, 2445, 645, 1545)
    }
    
    func testSimple() {
        let g = Simple()
        let lexers = Lexers<Character>()
        lexers.add(lexer: CharLexer(), for: g.Char)
        let parser = Parser(grammar: g, lexers: lexers)

        func run(_ input : String, _ S : NONTERMINAL, matches : Bool) {
            let parseResult = parser.parse(input: ArrayInput(input), position: 0, symbol: S, param: UNIT.singleton)
            switch parseResult {
            case .failed: XCTAssertFalse(matches)
            case let .success(length: length, results: parseResults):
                XCTAssertEqual(parseResults.count, 1)
                XCTAssertTrue(matches)
                XCTAssertEqual(length, input.count)
            }
        }
        
        run("A", g.A, matches: true)
        run("", g.A, matches: false)
        run("B", g.A, matches: false)
    }
    
    func testRegex() {
        let g = Regex()
        let lexers = Lexers<Character>()
        lexers.add(lexer: CharLexer(), for: g.Char)
        let parser = Parser(grammar: g, lexers: lexers)

        func run(_ input : String, _ S : NONTERMINAL, matches : Bool) {
            let parseResult = parser.parse(input: ArrayInput(input), position: 0, symbol: S, param: UNIT.singleton)
            switch parseResult {
            case .failed: XCTAssertFalse(matches)
            case let .success(length: length, results: parseResults):
                if matches {
                    XCTAssertEqual(length, input.count)
                    XCTAssertEqual(parseResults.count, 1)
                } else {
                    XCTAssert(length < input.count)
                }
            }
        }
        
        run("", g.X, matches: false)
        run("B", g.X, matches: true)
        run("BC", g.X, matches: true)
        run("C", g.X, matches: false)
        run("ABC", g.X, matches: true)
        run("AAABC", g.X, matches: true)
        run("AAAB", g.X, matches: true)
        run("AAAC", g.X, matches: false)
        run("", g.Y, matches: false)
        run("A", g.Y, matches: false)
        run("B", g.Y, matches: false)
        run("C", g.Y, matches: false)
        run("AB", g.Y, matches: false)
        run("AC", g.Y, matches: true)
        run("BC", g.Y, matches: true)
        run("CB", g.Y, matches: false)
        run("ACBC", g.Y, matches: true)
        run("BCAC", g.Y, matches: true)
        run("BCACACACACBCBCBCBCBC", g.Y, matches: true)
        run("", g.Z, matches: true)
        run("BBBBBBB", g.Z, matches: true)
        run("A", g.Z, matches: false)
    }


}
