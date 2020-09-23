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
            
    internal init(position : Position, terminal1 : IndexedSymbolName, terminal2 : IndexedSymbolName) {
        self.id = TerminalPriorityId()
        self.position = position
        self.terminal1 = terminal1
        self.terminal2 = terminal2
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
