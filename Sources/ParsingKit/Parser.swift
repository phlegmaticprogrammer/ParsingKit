import FirstOrderDeepEmbedding
import EarleyLocalLexing
import Foundation
import DynamicCodable

public indirect enum ParseTree : Hashable, Codable {
    
    public enum CodingError : Error {
        case cannotEncode(AnyHashable)
    }
    
    public struct Key : Hashable, Codable {
        
        public let symbol : SymbolName
        
        public let startPosition : Int
        
        public let endPosition : Int
        
        public let inputParam : AnyHashable
        
        public let outputParam : AnyHashable
    
        public var length : Int {
            return endPosition - startPosition
        }
        
        private enum CodingKeys : String, CodingKey {
            case symbol
            case startPosition
            case endPosition
            case inputParam
            case outputParam
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(symbol.name, forKey: .symbol)
            try container.encode(startPosition, forKey: .startPosition)
            try container.encode(endPosition, forKey: .endPosition)
            guard let input = inputParam as? DynamicCodable else {
                throw CodingError.cannotEncode(inputParam)
            }
            try container.encode(input, forKey: .inputParam)
            guard let output = outputParam as? DynamicCodable else {
                throw CodingError.cannotEncode(outputParam)
            }
            try container.encode(output, forKey: .outputParam)
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            symbol = SymbolName(try values.decode(String.self, forKey: CodingKeys.symbol))
            startPosition = try values.decode(Int.self, forKey: .startPosition)
            endPosition = try values.decode(Int.self, forKey: .endPosition)
            inputParam = try values.decode(DynamicCodable.self, forKey: .inputParam).value
            outputParam = try values.decode(DynamicCodable.self, forKey: .outputParam).value
        }
        
        public init(symbol : SymbolName, startPosition : Int, endPosition : Int, inputParam : AnyHashable, outputParam : AnyHashable) {
            self.symbol = symbol
            self.startPosition = startPosition
            self.endPosition = endPosition
            self.inputParam = inputParam
            self.outputParam = outputParam
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
    
    private enum EnumCase : Int, Codable {
        case rule
        case forest
    }
    
    private enum CodingKeys : String, CodingKey {
        case enumCase
        case key
        case ruleId
        case trees
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch (try container.decode(EnumCase.self, forKey: .enumCase)) {
        case .rule:
            let key = try container.decode(Key.self, forKey: .key)
            let id = try container.decode(RuleId.self, forKey: .ruleId)
            let rhs = try container.decode([ParseTree].self, forKey: .trees)
            self = ParseTree.rule(id: id, key: key, rhs: rhs)
        case .forest:
            let key = try container.decode(Key.self, forKey: .key)
            let trees = try container.decode([ParseTree].self, forKey: .trees)
            self = ParseTree.forest(key: key, trees: Set(trees))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .rule(id: id, key: key, rhs: rhs):
            try container.encode(EnumCase.rule, forKey: .enumCase)
            try container.encode(key, forKey: .key)
            try container.encode(id, forKey: .ruleId)
            try container.encode(rhs, forKey: .trees)
        case let .forest(key: key, trees: trees):
            try container.encode(EnumCase.forest, forKey: .enumCase)
            try container.encode(key, forKey: .key)
            try container.encode(Array(trees), forKey: .trees)
        }
    }
    
    public func mapKey(transform : (Key) -> Key) -> ParseTree {
        switch self {
        case let .forest(key: key, trees: trees):
            let transformedKey = transform(key)
            let transformedTrees = trees.map { tree in tree.mapKey(transform: transform) }
            return .forest(key: transformedKey, trees: Set(transformedTrees))
        case let .rule(id: id, key: key, rhs: rhs):
            let transformedKey = transform(key)
            let transformedRhs = rhs.map { tree in tree.mapKey(transform: transform) }
            return .rule(id: id, key: transformedKey, rhs: transformedRhs)
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
