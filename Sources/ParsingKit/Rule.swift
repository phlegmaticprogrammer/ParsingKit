import FirstOrderDeepEmbedding
import Foundation

/// The name of a rule. Must be either anonymous or unique among the rules for a given symbol.
public struct RuleName: Hashable {
    
    public let name : String?
        
    /// Creates a RuleName.
    public init(name : String?) {
        self.name = name
    }
    
    /// Whether this name is anonymous.
    public var isAnonymous : Bool {
        return name == nil
    }
}

public enum RuleBodyElem : HasPosition {

    case symbol(symbol : IndexedSymbolName, position : Position)

    case assignment(left: Term, right: Term, position : Position)

    case condition(cond : Term, position : Position)
    
    var position : Position {
        switch self {
        case let .symbol(symbol: _, position: p): return p
        case let .assignment(left: _, right: _, position: p): return p
        case let .condition(cond: _, position: p): return p
        }
    }

}

public protocol RuleBody {

    var ruleBodyElems : [RuleBodyElem] { get }
    
}

struct RuleBodyImpl : RuleBody {
    
    var ruleBodyElems: [RuleBodyElem] = []
            
}

@_functionBuilder
public class RuleBodyBuilder {
    
    public static func buildBlock(_ components : RuleBody...) -> RuleBody  {
        var body = RuleBodyImpl()
        for c in components {
            body.ruleBodyElems.append(contentsOf: c.ruleBodyElems)
        }
        return body
    }
    
    public static func buildIf(_ component : RuleBody?) -> RuleBody {
        return component ?? RuleBodyImpl()
    }
    
}

infix operator <== : AssignmentPrecedence
infix operator <-- : AssignmentPrecedence
infix operator --> : AssignmentPrecedence
prefix operator %?

public func <== <T : Sort>(left : T, right : T) -> RuleBody {
    return RuleBodyImpl(ruleBodyElems: [.assignment(left: left.inhabitant, right: right.inhabitant, position: .unknown)])
}

public func --> <In : Sort, Out : Sort>(output : Out, target : Symbol<In, Out>) -> RuleBody {
    return target.out <== output
}

public func <-- <In : Sort, Out : Sort>(target : Symbol<In, Out>, input : In) -> RuleBody {
    return target.in <== input
}

public prefix func %?(_ condition : BOOL) -> RuleBody {
    return RuleBodyImpl(ruleBodyElems: [.condition(cond: condition.inhabitant, position: .unknown)])
}

public func collectRuleBody(_ ruleBodies : [RuleBody]) -> RuleBody {
    var elems : [RuleBodyElem] = []
    for body in ruleBodies {
        elems.append(contentsOf: body.ruleBodyElems)
    }
    return RuleBodyImpl(ruleBodyElems: elems)
}

public func collectRuleBody(@RuleBodyBuilder _ ruleBodyBuilder : () -> RuleBody) -> RuleBody {
    return ruleBodyBuilder()
}

public struct Rule : GrammarElement, HasPosition {
    
    public let name : RuleName

    public let position : Position

    public let symbol : IndexedSymbolName

    public let body : [RuleBodyElem]

    internal init(name : RuleName, position : Position, symbol : IndexedSymbolName, body : [RuleBodyElem]) {
        self.name = name
        self.position = position
        self.symbol = symbol
        self.body = body
    }
        
    public func grammarComponents() -> [GrammarComponent] {
        return [.rule(rule: self)]
    }
    
    internal func find(_ s : IndexedSymbolName) -> Int? {
        if symbol == s { return 0 }
        var index = 1
        for e in body {
            switch e {
            case let .symbol(symbol: symbol, position: _):
                if symbol == s { return index }
                index += 1
            default: break
            }
        }
        return nil
    }
    
    internal func rhsCount() -> Int {
        var count = 0
        for e in body {
            switch e {
            case .symbol: count += 1
            default: break
            }
        }
        return count
    }


}
