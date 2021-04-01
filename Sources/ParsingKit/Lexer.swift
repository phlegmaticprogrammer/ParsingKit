import FirstOrderDeepEmbedding
import EarleyLocalLexing

public typealias Input = EarleyLocalLexing.Input

public final class ArrayInput<Char> : Input<Char> {
    
    public let characters : [Char]
    public let offset : Int
    
    public init<S : Sequence>(_ characters : S, offset : Int = 0) where S.Element == Char {
        self.characters = Array(characters)
        self.offset = offset
    }
    
    public override subscript(position: Int) -> Char? {
        let i = position - offset
        guard i < characters.count else { return nil }
        return characters[i]
    }
    
}


public protocol Lexer {
    
    associatedtype Char
    
    associatedtype In : ASort
    
    associatedtype Out : ASort

    func lex(input : Input<Char>, position : Int, in : In.Native) -> ParseResult<Out.Native>

}

internal class AnyLexer<Char> {
    
    private typealias AnyLexerFunction = (_ input : Input<Char>, _ position : Int, _ in : AnyHashable)  -> ParseResult<AnyHashable>
    
    private let lexerFunction : AnyLexerFunction
    
    let `in` : Sort
    
    let out : Sort
    
    init<L : Lexer>(lexer : L) where L.Char == Char {
        func lex(input : Input<Char>, position : Int, in : AnyHashable)  -> ParseResult<AnyHashable> {
            let result = lexer.lex(input: input, position: position, in: `in` as! L.In.Native)
            return result.convertOut()
        }
        self.lexerFunction = lex
        self.in = L.In()
        self.out = L.Out()
    }
    
    func lex(input : Input<Char>, position : Int, in : AnyHashable) -> ParseResult<AnyHashable> {
        return lexerFunction(input, position, `in`)
    }
        
}

public class Lexers<Char> {
    
    private var _lexers : [SymbolName : AnyLexer<Char>]
    
    public init() {
        _lexers = [:]
    }
    
    public func add<L : Lexer>(lexer : L, for terminal : Terminal<L.In, L.Out>) where L.Char == Char {
        let name = terminal.name.name
        guard _lexers[name] == nil else { fatalError("duplicate lexer for terminal '\(name)'") }
        _lexers[name] = AnyLexer(lexer: lexer)
    }
    
    public func add<L : Lexer>(lexer : L, for name : SymbolName) where L.Char == Char {
        guard _lexers[name] == nil else { fatalError("duplicate lexer for terminal '\(name)'") }
        _lexers[name] = AnyLexer(lexer: lexer)
    }

    internal var lexers : [SymbolName : AnyLexer<Char>] { return _lexers }

}

public class ByteLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = INT
    
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> ParseResult<Int> {
        guard let char = input[position] else { return .failed(position: position) }
        return .success(length: 1, results: [Int(char) : nil])
    }

}

public class CharLexer : Lexer {
    
    public typealias Char = Character
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
    
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> ParseResult<Character> {
        guard let char = input[position] else { return .failed(position: position) }
        return .success(length: 1, results: [char : nil])
    }

}

public class LiteralCharLexer : Lexer {
    
    public typealias Char = Character
    
    public typealias In = UNIT
    
    public typealias Out = UNIT
    
    private let literal : [Character]
    
    public init(literal : String) {
        self.literal = Array(literal)
    }
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> ParseResult<Out.Native> {
        let count = literal.count
        for i in 0 ..< count {
            guard let char = input[position + i], char == literal[i] else { return .failed(position: position + i) }
        }
        return .success(length: count, results: [UNIT.singleton : nil])
    }

}

public class UTF8CharLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
                
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> ParseResult<Character> {
        // This code works under two assumptions, both of which seem to be true:
        // 1) If a sequence of codepoints does not form a valid character, then appending codepoints to it does not yield a valid character
        // 2) Appending codepoints to a sequence of codepoints does not decrease its length in terms of extended grapheme clusters
        
        var chars : [UInt8] = []
        var result : String = ""
        var resultPosition = position
        func value() -> ParseResult<Character> {
            guard let character = result.first else { return .failed(position: position) }
            return .success(length: resultPosition - position, results: [character : nil])
        }
        var p = position
        while p - resultPosition <= 4 {
            guard let char = input[p] else { return value() }
            chars.append(char)
            p += 1
            guard let s = String(bytes: chars, encoding: .utf8) else { continue }
            guard s.count == 1 else { return value() }
            result = s
            resultPosition = p
        }
        return value()
    }
    
}

