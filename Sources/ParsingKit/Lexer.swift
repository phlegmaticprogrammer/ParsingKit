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

public enum LexingMode {
    case longestMatch
    case not
    case andLongestMatch
}


public protocol Lexer {
    
    associatedtype Char
    
    associatedtype In : ASort
    
    associatedtype Out : ASort

    func lex(input : Input<Char>, mode : LexingMode, position : Int, in : In.Native) -> (length : Int, out: Out.Native)?

}

internal class AnyLexer<Char> {
    
    private typealias AnyLexerFunction = (_ input : Input<Char>, _ mode : LexingMode, _ position : Int, _ in : AnyHashable)  -> (length : Int, out: AnyHashable)?
    
    private let lexerFunction : AnyLexerFunction
    
    let `in` : Sort
    
    let out : Sort
    
    init<L : Lexer>(lexer : L) where L.Char == Char {
        func lex(input : Input<Char>, mode : LexingMode, position : Int, in : AnyHashable)  -> (length : Int, out: AnyHashable)? {
            return lexer.lex(input: input, mode: mode, position: position, in: `in` as! L.In.Native)
        }
        self.lexerFunction = lex
        self.in = L.In()
        self.out = L.Out()
    }
    
    func lex(input : Input<Char>, mode : LexingMode, position : Int, in : AnyHashable) -> (length : Int, out: AnyHashable)? {
        return lexerFunction(input, mode, position, `in`)
    }
        
}

public class Lexers<Char> {
    
    private var _lexers : [SymbolName : (LexingMode, AnyLexer<Char>)]
    
    public init() {
        _lexers = [:]
    }
    
    public func add<L : Lexer>(lexer : L, for terminal : Terminal<L.In, L.Out>, mode : LexingMode) where L.Char == Char {
        let name = terminal.name.name
        guard _lexers[name] == nil else { fatalError("duplicate lexer for terminal '\(name)'") }
        _lexers[name] = (mode, AnyLexer(lexer: lexer))
    }
    
    internal var lexers : [SymbolName : (LexingMode, AnyLexer<Char>)] { return _lexers }

}

fileprivate func adjustLexingResult<R>(mode : LexingMode, result : (length : Int, out: R)?) -> (length : Int, out : R)? {
    fatalError()
    //switch
}

public class ByteLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = INT
    
    public init() {}
    
    private func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Int)? {
        guard let char = input[position] else { return nil }
        return (length: 1, out: Int(char))
    }

    public func lex(input : Input<Char>, mode : LexingMode, position : Int, in : In.Native) -> (length : Int, out: Out.Native)? {
        return adjustLexingResult(mode: mode, result: lex(input: input, position: position, in: `in`))
    }

}

public class CharLexer : Lexer {
    
    public typealias Char = Character
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
    
    public init() {}
    
    private func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Character)? {
        guard let char = input[position] else { return nil }
        return (length: 1, out: char)
    }

    public func lex(input : Input<Char>, mode : LexingMode, position : Int, in : In.Native) -> (length : Int, out: Out.Native)? {
        return adjustLexingResult(mode: mode, result: lex(input: input, position: position, in: `in`))
    }
}

public class UTF8CharLexer : Lexer {
    
    public typealias Char = UInt8
    
    public typealias In = UNIT
    
    public typealias Out = CHAR
                
    public init() {}
    
    private func lex(input : Input<Char>, position : Int, in : In.Native) -> (length : Int, out: Character)? {
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
    
    public func lex(input : Input<Char>, mode : LexingMode, position : Int, in : In.Native) -> (length : Int, out: Out.Native)? {
        return adjustLexingResult(mode: mode, result: lex(input: input, position: position, in: `in`))
    }
}

