import FirstOrderDeepEmbedding
import EarleyLocalLexing

public typealias Input = EarleyLocalLexing.Input

public final class ArrayInput<Char> : Input<Char> {
    
    public let characters : [Char]
    
    public init<S : Sequence>(_ characters : S) where S.Element == Char {
        self.characters = Array(characters)
    }
    
    public override subscript(position: Int) -> Char? {
        guard position < characters.count else { return nil }
        return characters[position]
    }
    
}

public protocol Lexer {
    
    associatedtype Char
    
    associatedtype In : ASort
    
    associatedtype Out : ASort

    func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Out.Native)?

}

internal class AnyLexer<Char> {
    
    private typealias AnyLexerFunction = (_ input : Input<Char>, _ position : Int, _ in : AnyHashable)  -> (length : Int, out: AnyHashable)?
    
    private let lexerFunction : AnyLexerFunction
    
    let `in` : Sort
    
    let out : Sort
    
    init<L : Lexer>(lexer : L) where L.Char == Char {
        func lex(input : Input<Char>, position : Int, in : AnyHashable)  -> (length : Int, out: AnyHashable)? {
            return lexer.lex(input: input, position: position, in: `in` as! L.In.Native)
        }
        self.lexerFunction = lex
        self.in = L.In()
        self.out = L.Out()
    }
    
    func lex(input : Input<Char>, position : Int, in : AnyHashable) -> (length : Int, out: AnyHashable)? {
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
    
    internal var lexers : [SymbolName : AnyLexer<Char>] { return _lexers }

}

public class ByteLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = INT
    
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Int)? {
        guard let char = input[position] else { return nil }
        return (length: 1, out: Int(char))
    }

}

public class CharLexer : Lexer {
    
    public typealias Char = Character
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
    
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Character)? {
        guard let char = input[position] else { return nil }
        return (length: 1, out: char)
    }

}

public class UTF8CharLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
                
    public init() {}
    
    public func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Character)? {
        // This code works under two assumptions, both of which seem to be true:
        // 1) If a sequence of codepoints does not form a valid character, then appending codepoints to it does not yield a valid character
        // 2) Appending codepoints to a sequence of codepoints does not decrease its length in terms of extended grapheme clusters
        
        var chars : [UInt8] = []
        var result : String = ""
        var resultPosition = position
        func value() -> (length : Int, out : Character)? {
            guard let character = result.first else { return nil }
            return (length: resultPosition - position, out: character)
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

