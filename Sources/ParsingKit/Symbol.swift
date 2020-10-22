import FirstOrderDeepEmbedding

/// The type of the name of a `Symbol`.
public struct SymbolName : Hashable, ExpressibleByStringLiteral, CustomStringConvertible, Codable {
    
    public typealias StringLiteralType = String
    
    /// The literal symbol name.
    public let name : String
    
    public init(stringLiteral : String) {
        self.name = stringLiteral
    }
    
    public init(_ name : String) {
        self.name = name
    }
    
    public var description: String {
        return name
    }
}

/// An `IndexedSymbol` designates either a terminal or a nonterminal.
///
/// `IndexedSymbol`s are used to refer to terminals and nonterminals in grammar rules.
/// In order to distinguish between different occurrences of the same terminal / nonterminal, indexed symbols carry an optional `index` in addition to the actual `name`.
///
public struct IndexedSymbolName : CustomStringConvertible, Hashable {
    
    /// The name of the terminal or nonterminal that this indexed symbol designates.
    public let name : SymbolName
    
    /// An optional index to distinguish between different occurrences of the same terminal / nonterminal. A value of `0` stands for this symbol having no index.
    public let index : AnyHashable
    
    /// Constructs an indexed symbol.
    /// - parameter name: The name of this indexed symbol.
    /// - parameter index: An optional index, to distinguish between different occurrences of the same terminal / nonterminal.
    public init(_ name : SymbolName, _ index : AnyHashable = 0) {
        self.name = name
        self.index = index
    }
    
    /// Whether this symbol has an index or not. An index of `0` counts as having no index.
    /// - returns: `false` if `index` is `0`, otherwise `true`
    public var hasIndex : Bool {
        guard let i = index as? Int else { return false }
        return i != 0
    }
    
    public var description : String {
        if hasIndex {
            return "\(name)[\(index)]"
        } else {
            return "\(name)"
        }
    }
}

public enum SymbolKind : Hashable {
    
    case terminal(in : Sort, out : Sort)
    
    case nonterminal(in : Sort, out : Sort)
    
    public var isTerminal : Bool {
        switch self {
        case .terminal: return true
        case .nonterminal: return false
        }
    }

    public var isNonterminal : Bool {
        switch self {
        case .terminal: return false
        case .nonterminal: return true
        }
    }
    
    public var `in` : Sort {
        switch self {
        case let .terminal(in: `in`, out: _): return `in`
        case let .nonterminal(in: `in`, out: _): return `in`
        }
    }
    
    public var out : Sort {
        switch self {
        case let .terminal(in: _, out: out): return out
        case let .nonterminal(in: _, out: out): return out
        }
    }
    
    public static func == (left : SymbolKind, right : SymbolKind) -> Bool {
        switch (left, right) {
        case let (.terminal(in: lin, out: lout), .terminal(in: rin, out: rout)):
            return lin.sortname == rin.sortname && lout.sortname == rout.sortname
        case let (.nonterminal(in: lin, out: lout), .nonterminal(in: rin, out: rout)):
            return lin.sortname == rin.sortname && lout.sortname == rout.sortname
        default:
            return false
        }
        
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(isTerminal)
        hasher.combine(`in`.sortname)
        hasher.combine(out.sortname)
    }
    
}

internal enum SymbolVar : Hashable, CustomStringConvertible {
    case In(symbol : IndexedSymbolName)
    case Out(symbol : IndexedSymbolName)
    
    var symbol : IndexedSymbolName {
        switch self {
        case let .In(symbol: symbol): return symbol
        case let .Out(symbol: symbol): return symbol
        }
    }
    
    var description : String {
        switch self {
        case let .In(symbol: symbol): return "\(symbol).in"
        case let .Out(symbol: symbol): return "\(symbol).out"
        }
    }
    
    func sort(grammar : Grammar) -> Sort? {
        guard let kind = grammar.kindOf(symbol.name) else { return nil }
        switch self {
        case .In: return kind.in
        case .Out: return kind.out
        }
    }
    
    static func extract(from term : Term) -> SymbolVar? {
        switch term {
        case let .Var(id: _, name: name): return name as? SymbolVar
        default: return nil
        }
    }
}

postfix operator ~

public class Symbol<In : Sort, Out : Sort> : RuleBody {

    public let name : IndexedSymbolName
    
    public let kind : SymbolKind
            
    public var `in` : In {
        In.Var(SymbolVar.In(symbol: name))
    }
    
    public var out : Out {
        Out.Var(SymbolVar.Out(symbol: name))
    }
    
    public static postfix func ~(symbol : Symbol<In, Out>) -> Out {
        return symbol.out
    }

    public static prefix func ~(symbol : Symbol<In, Out>) -> In {
        return symbol.in
    }
    
    public subscript(_ index : AnyHashable) -> Self {
        let newName = IndexedSymbolName(name.name, index)
        return Self(name: newName, kind: kind)
    }
    
    private func extractRuleBodyElements(_ ruleBodies : [RuleBody]) -> [RuleBodyElem] {
        var elems : [RuleBodyElem] = []
        for ruleBody in ruleBodies {
            elems.append(contentsOf: ruleBody.ruleBodyElems)
        }
        return elems
    }

    public func rule(name : RuleName = RuleName(), file : String = #file, line : Int = #line, @RuleBodyBuilder _ ruleBodyBuilder : () -> RuleBody) -> GrammarElement {
        return Rule(name : name, position : .position(file: file, line: line), symbol: self.name, body: ruleBodyBuilder().ruleBodyElems)
    }

    public func rule(name : RuleName = RuleName(), file : String = #file, line : Int = #line, _ ruleBodies : [RuleBody]) -> GrammarElement {
        let elems = extractRuleBodyElements(ruleBodies)
        return Rule(name : name, position : .position(file: file, line: line), symbol: self.name, body: elems)
    }
    
    public var ruleBodyElems: [RuleBodyElem] {
        return [.symbol(symbol: name, position: .unknown)]
    }

    internal required init(name : IndexedSymbolName, kind : SymbolKind) {
        self.name = name
        self.kind = kind
    }

    internal required init(name : IndexedSymbolName) {
        fatalError("needs to be overriden in subclass")
    }
    
}
    
public final class Terminal<In : Sort, Out : Sort> : Symbol<In, Out> {

    internal required init(name : IndexedSymbolName, kind : SymbolKind) {
        super.init(name : name, kind : kind)
    }

    internal required init(name : IndexedSymbolName) {
        super.init(name : name, kind : .terminal(in: In(), out: Out()))
    }

}

public final class Nonterminal<In : Sort, Out : Sort> : Symbol<In, Out> {

    internal required init(name : IndexedSymbolName, kind : SymbolKind) {
        super.init(name : name, kind : kind)
    }

    internal required init(name : IndexedSymbolName) {
        super.init(name : name, kind : .nonterminal(in: In(), out: Out()))
    }

}

public typealias TERMINAL = Terminal<UNIT, UNIT>

public typealias NONTERMINAL = Nonterminal<UNIT, UNIT>

public typealias SYMBOL = Symbol<UNIT, UNIT>
