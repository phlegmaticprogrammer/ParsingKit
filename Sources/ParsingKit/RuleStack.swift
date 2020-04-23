import FirstOrderDeepEmbedding

struct RuleStack {
    
    let rule : Rule
    
    let lhs : IndexedSymbolName
    
    let termStore : TermStore

    private var rhs : [IndexedSymbolName] = []
    private var assignedIns : [IndexedSymbolName] = []
    private var assignedOut : Bool = false

    init(rule : Rule, lhs : IndexedSymbolName, store : TermStore) {
        self.rule = rule
        self.lhs = lhs
        self.termStore = store
    }
    
    func typingEnvironment(grammar : Grammar) -> Environment<SortName> {
        func environment(v : VarName) -> SortName? {
            guard let name = v as? SymbolVar else { return nil }
            let symbol = name.symbol
            guard symbolHasBeenIntroduced(symbol) else { return nil }
            guard let kind = grammar.kindOf(symbol.name) else { return nil }
            switch name {
            case .In: return kind.in.sortname
            case .Out: return kind.out.sortname
            case .Length: return nil
            }
        }
        return environment
    }
    
    func stackElements() -> [IndexedSymbolName] {
        return rhs
    }
    
    func store(_ term : Term) -> TermStore.Id {
        return termStore.store(term)
    }

    func missingAssignments() -> (ins : [IndexedSymbolName], out : Bool) {
        var ins : [IndexedSymbolName] = []
        for symbol in rhs {
            if !isContained(symbol, in: assignedIns) {
                ins.append(symbol)
            }
        }
        return (ins: ins, out: !assignedOut)
    }

    func symbolHasBeenIntroduced(_ symbol : IndexedSymbolName) -> Bool {
        if symbol == lhs { return true }
        for s in rhs {
            if s == symbol { return true }
        }
        return false
    }

    mutating func appendSymbol(_ symbol : IndexedSymbolName) -> Bool {
       guard !symbolHasBeenIntroduced(symbol) else { return false }
       rhs.append(symbol)
       return true
    }

    private func isContained(_ symbol : IndexedSymbolName, in symbols : [IndexedSymbolName]) -> Bool {
       for s in symbols {
           if s == symbol { return true }
       }
       return false
    }

    mutating func assignIn(_ symbol : IndexedSymbolName) -> Bool {
       guard symbolHasBeenIntroduced(symbol) else { return false }
       guard !isContained(symbol, in: assignedIns) else { return false }
       assignedIns.append(symbol)
       return true
    }

    mutating func assignOut(_ symbol : IndexedSymbolName) -> Bool {
        guard symbol == lhs else { return false }
        guard !assignedOut else { return false }
        assignedOut = true
        return true
    }
    
    mutating func assign(_ symbolVar : SymbolVar) -> Bool {
        switch symbolVar {
        case let .In(symbol: symbol): return assignIn(symbol)
        case let .Out(symbol: symbol): return assignOut(symbol)
        case .Length: return false
        }
    }
    
    func allowedSymbolsInAssignmentTo(_ symbol : IndexedSymbolName) -> Set<SymbolVar> {
        var allowed : Set<SymbolVar> = [.In(symbol: lhs)]
        for r in rhs {
            if r == symbol { return allowed }
            allowed.insert(.In(symbol: r))
            allowed.insert(.Out(symbol: r))
        }
        return allowed
    }

}
