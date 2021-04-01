import FirstOrderDeepEmbedding
import EarleyLocalLexing

public indirect enum ParseTree : Hashable {
    
    public struct Key : Hashable {
        
        public let symbol : SymbolName
        
        public let startPosition : Int
        
        public let endPosition : Int
        
        public let inputParam : AnyHashable
        
        public let outputParam : AnyHashable
    
        public var length : Int {
            return endPosition - startPosition
        }
    }
    
    case rule(id : RuleId, key : Key, rhs : [ParseTree])

    case forest(key : Key, trees : Set<ParseTree>)
    
    public var key : Key {
        switch self {
        case let .rule(id: _, key: key, rhs: _): return key
        case let .forest(key: key, trees: _): return key
        }
    }
    
    internal func collect(trees : inout Set<ParseTree>) {
        switch self {
        case .rule: trees.insert(self)
        case let .forest(key: _, trees: nestedTrees):
            for tree in nestedTrees {
                tree.collect(trees: &trees)
            }
        }
    }
    
    internal static func leaf(key : Key) -> ParseTree {
        return .forest(key: key, trees: [])
    }
    
    public var isAmbiguous : Bool {
        switch self {
        case let .forest(key: _, trees: trees):
            if trees.count > 1 { return true }
            for tree in trees {
                if tree.isAmbiguous { return true }
            }
            return false
        case let .rule(id: _, key: _, rhs: rhs):
            for tree in rhs {
                if tree.isAmbiguous { return true }
            }
            return false
        }
    }

}

public enum ParseResult<Out : Hashable> {

    case failed(position : Int)
    
    case success(length : Int, results : [Out : ParseTree?])
    
    public func asTokens() -> Set<Token<Out, ParseTree>> {
        switch self {
        case .failed: return []
        case let .success(length: length, results: results):
            var tokens : Set<Token<Out, ParseTree>> = []
            for (out, optTree) in results {
                //let tree = optTree ?? makeDefaultParseTree(length, out)
                let token = Token(length: length, outputParam: out, result: optTree)
                tokens.insert(token)
            }
            return tokens
        }
    }
    
    public func convertOut<NewOut>() -> ParseResult<NewOut> {
        switch self {
        case .failed(position: let position): return .failed(position: position)
        case let .success(length: length, results: results):
            var converted : [NewOut : ParseTree?] = [:]
            for (out, optTree) in results {
                converted[out as! NewOut] = optTree
            }
            return .success(length: length, results: converted)
        }
    }

}

public class Parser<Char> {
    
    private let parsing : Parsing<Char>

    public init(grammar : Grammar, lexers : Lexers<Char>) {
        // sanity check if the lexers actually correspond to terminals in the grammar
        for (name, lexer) in lexers.lexers {
            guard let kind = grammar.kindOf(name), kind.isTerminal else { fatalError("A lexer is associated with terminal '\(name)' which is not part of the grammar.") }
            guard kind.in.sortname == lexer.in.sortname && kind.out.sortname == lexer.out.sortname else { fatalError("The lexer associated with terminal '\(name)' has incompatible input or output sorts.") }
            guard grammar.lookaheads[name] == nil else { fatalError("Lookahead terminal cannot have custom lexer.")}
        }
        parsing = Parsing(grammar: grammar, lexers: lexers)
    }
    
    public func parse<In : ASort, Out : ASort>(input : Input<Char>, position : Int = 0, start : Nonterminal<In, Out>, param : In.Native) -> ParseResult<Out.Native> {
        return parsing.parse(input: input, position: position, symbol: start, param: param)
    }

}
