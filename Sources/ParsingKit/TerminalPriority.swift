import FirstOrderDeepEmbedding

/// The unique identifier of a priority.
public final class TerminalPriorityId: Hashable {
        
    public static func == (left: TerminalPriorityId, right: TerminalPriorityId) -> Bool {
        return left === right
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    /// Creates a new PriorityId which is unequal to any other existing PriorityId.
    public init() {}
    
}

public struct TerminalPriority : GrammarElement, HasPosition, Hashable {
    
    public let id : TerminalPriorityId
    
    public let position : Position
    
    public let terminal1 : IndexedSymbolName // lower priority terminal
    
    public let terminal2 : IndexedSymbolName // higher priority terminal
    
    public struct Attributes : Hashable {
        let paramIn : AnyHashable
        let paramOut : AnyHashable
        let length : Int
    }
    
    public enum Condition {
        case True
        case False
        case ifGreaterLength
        case ifGreaterOrEqualLength
        case ifLessLength
        case ifLessOrEqualLength
        case ifSameLength
        case ifDifferentLength
                
        public static func from(less : Bool, equal : Bool, greater : Bool) -> Condition {
            switch (less, equal, greater) {
            case (true, true, true): return .True
            case (false, false, false): return .False
            case (false, false, true): return .ifGreaterLength
            case (false, true, true): return .ifGreaterOrEqualLength
            case (true, false, false): return .ifLessLength
            case (true, true, false): return .ifLessOrEqualLength
            case (false, true, false): return .ifSameLength
            case (true, false, true): return .ifDifferentLength
            }
        }
        
        public func split() -> (less : Bool, equal : Bool, greater : Bool)  {
            switch self {
            case .True: return (true, true, true)
            case .False: return (false, false, false)
            case .ifGreaterLength: return (false, false, true)
            case .ifGreaterOrEqualLength: return (false, true, true)
            case .ifLessLength: return (true, false, false)
            case .ifLessOrEqualLength: return (true, true, false)
            case .ifSameLength: return (false, true, false)
            case .ifDifferentLength: return (true, false, true)
            }
        }
        
        public func eval(lower : Attributes, higher : Attributes) -> Bool {
            switch self {
            case .True: return true
            case .False: return false
            case .ifGreaterLength: return lower.length > higher.length
            case .ifGreaterOrEqualLength: return lower.length >= higher.length
            case .ifLessLength: return lower.length < higher.length
            case .ifLessOrEqualLength: return lower.length <= higher.length
            case .ifSameLength: return lower.length == higher.length
            case .ifDifferentLength: return lower.length != higher.length
            }
        }
        
        public var reversed : Condition {
            switch self {
            case .True, .False, .ifSameLength: return self
            case .ifGreaterLength: return .ifLessLength
            case .ifLessLength: return .ifGreaterLength
            case .ifGreaterOrEqualLength: return .ifLessOrEqualLength
            case .ifLessOrEqualLength: return .ifGreaterOrEqualLength
            case .ifDifferentLength: return .ifDifferentLength
            }
        }
        
        public static func or(_ u : Condition, _ v : Condition) -> Condition {
            let usplit = u.split()
            let vsplit = v.split()
            return Condition.from(less: usplit.less || vsplit.less,
                                  equal: usplit.equal || vsplit.equal,
                                  greater: usplit.greater || vsplit.greater)
        }

        public static func and(_ u : Condition, _ v : Condition) -> Condition {
            let usplit = u.split()
            let vsplit = v.split()
            return Condition.from(less: usplit.less && vsplit.less,
                                  equal: usplit.equal && vsplit.equal,
                                  greater: usplit.greater && vsplit.greater)
        }
    }
        
    public let when : Condition
            
    internal init(position : Position, terminal1 : IndexedSymbolName, terminal2 : IndexedSymbolName, when : Condition = .True) {
        self.id = TerminalPriorityId()
        self.position = position
        self.terminal1 = terminal1
        self.terminal2 = terminal2
        self.when = when
    }
    
    public static func == (left : TerminalPriority, right : TerminalPriority) -> Bool {
        return left.id == right.id
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }
    
    public func grammarComponents() -> [GrammarComponent] {
        return [.terminalPriority(priority: self)]
    }
    
    internal func typingEnvironment(grammar : Grammar) -> Environment<SortName> {
        func environment(varname : VarName) -> SortName? {
            guard let symbolVar = varname as? SymbolVar else { return nil }
            guard symbolVar.symbol == terminal1 || symbolVar.symbol == terminal2 else { return nil }
            return symbolVar.sort(grammar: grammar)?.sortname
        }
        return environment
    }
    
}
