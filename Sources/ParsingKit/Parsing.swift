import FirstOrderDeepEmbedding
import EarleyLocalLexing

fileprivate class L<Char> : EarleyLocalLexing.Lexer {
    
    typealias Param = AnyHashable
    
    typealias Result = ParseTree
    
    let lexers : [Int : AnyLexer<Char>]
    
    init(lexers : [Int : AnyLexer<Char>]) {
        self.lexers = lexers
    }

    func parse(input: Input<Char>, position: Int, key: TerminalKey<Param>) -> Set<Token<Param, Result>> {
        guard let lexer = lexers[key.terminalIndex] else { return [] }
        guard let result = lexer.lex(input: input, position: position, in: key.inputParam) else { return [] }
        let token = Token<Param, Result>(length: result.length, outputParam: result.out, result: nil)
        return [token]
    }
    
}

fileprivate class S : EarleyLocalLexing.Selector {
        
    typealias Param = AnyHashable
    
    typealias Result = ParseTree
        
    typealias Priorities = [Int : Set<Int>] // maps each terminal to the set of terminals with LOWER priority
    
    let priorities : Priorities
    
    init(priorities : Priorities) {
        self.priorities = S.transitiveClosure(priorities)
    }

    struct T : Hashable {
        let terminalIndex : Int
        let inputParam : Param
        let outputParam : Param
    }
    
    private static func transitiveClosure(_ priorities : Priorities) -> Priorities {
        var currentClosure : Priorities = priorities
        var changed : Bool = false
        func step(_ terminals : Set<Int>) -> Set<Int> {
            var result = terminals
            for t in terminals {
                if let ts = currentClosure[t] {
                    result.formUnion(ts)
                }
            }
            if result.count != terminals.count {
                changed = true
            }
            return result
        }
        repeat {
            changed = false
            currentClosure = currentClosure.mapValues(step)
        } while changed
        return priorities
    }
        
    func select(from: Tokens<Param, Result>, alreadySelected: Tokens<Param, Result>) -> Tokens<Param, Result> {
        var forbidden : Set<Int> = []
        for (key, _) in alreadySelected {
            guard let prios = priorities[key.terminalIndex] else { continue }
            forbidden.formUnion(prios)
        }
        for (key, _) in from {
            guard let prios = priorities[key.terminalIndex] else { continue }
            forbidden.formUnion(prios)
        }
        var selected : Tokens<Param, Result> = [:]
        next_token:
        for (key, tokens) in from {
            if !forbidden.contains(key.terminalIndex) {
                selected[key] = tokens
            }
        }
        return alreadySelected.merging(selected) { t1, t2 in t1.union(t2) }
    }
    
}

fileprivate class C<Char> : EarleyLocalLexing.ConstructResult {
    
    typealias Param = AnyHashable
    
    typealias Result = ParseTree
    
    let terminals : [SymbolName]
    
    let nonterminals : [SymbolName]
    
    let symbols : Grammar.Symbols
    
    let rules : [Rule]
    
    init(terminals : [SymbolName], nonterminals : [SymbolName], symbols : Grammar.Symbols, rules : [Rule]) {
        self.terminals = terminals
        self.nonterminals = nonterminals
        self.symbols = symbols
        self.rules = rules
    }

    func transform(symbol : EarleyLocalLexing.Symbol) -> SymbolName {
        switch symbol {
        case let .nonterminal(index: index):
            return nonterminals[index]
        case let .terminal(index: index):
            return terminals[index]
        }
    }
    
    func transform(key : ItemKey<Param>) -> ParseTree.Key {
        return ParseTree.Key(symbol: transform(symbol: key.symbol),
                             startPosition: key.startPosition,
                             endPosition: key.endPosition,
                             inputParam: key.inputParam,
                             outputParam: key.outputParam)
    }
    
    func isDeep(symbol : SymbolName) -> Bool {
        return symbols[symbol]!.structure == .Deep
    }

    func evalRule<RHS>(input: Input<Char>, key: ItemKey<Param>, completed: RHS) -> Result where RHS : CompletedRightHandSide, Param == RHS.Param, Result == RHS.Result {
        let k = transform(key: key)
        guard isDeep(symbol: k.symbol) else { return ParseTree.leaf(key: k) }
        let id = ruleIds[completed.ruleIndex]
        let count = completed.count
        let rhs = (0 ..< count).map { i in completed.rhs(i+1).result }
        return .rule(id: id, key: k, rhs: rhs)
    }
    
    func terminal(key: ItemKey<AnyHashable>, result: ParseTree?) -> ParseTree {
        return result ?? ParseTree.leaf(key: transform(key: key))
    }
        
    func merge(key: ItemKey<Param>, results: [Result]) -> Result {
        let k = transform(key: key)
        guard isDeep(symbol: k.symbol) else { return ParseTree.leaf(key: k) }

        var collectedResults : Set<Result> = []
        for result in results {
            result.collect(trees: &collectedResults)
        }
        if collectedResults.count == 1 {
            return collectedResults.first!
        } else {
            return .forest(key: k, trees: collectedResults)
        }
    }
    
}

fileprivate class E : EarleyLocalLexing.EvalEnv {
    
    func copy() -> Self {
        return self
    }
    
}

fileprivate class Allocate : FirstOrderDeepEmbedding.ComputationOnTerms {

    /// `k` is the number of right hand side symbols that must have been already processed in order to evaluate `allocated`
    typealias Result = (k : Int, allocated : Term)

    /// number of symbols on right hand side of rule
    let N : Int
    
    /// output term assigned to left hand side symbol
    var output : Term?
    
    /// proxy for `Rule.find`
    let findInRule : (IndexedSymbolName) -> Int
    
    init(N : Int, findInRule : @escaping (IndexedSymbolName) -> Int) {
        self.N = N
        self.output = nil
        self.findInRule = findInRule
    }
    
    func computeVar(name: VarName) -> (k: Int, allocated: Term) {
        let v = name as! SymbolVar
        let k = findInRule(v.symbol)
        switch v {
        case .In:
            return (k: k, allocated: .Var(name: k == 0 ? 0 : 2 * k - 1))
        case .Out where k == 0:
            return (k: N, allocated: output!)
        case .Out:
            return (k: k, allocated: .Var(name: 2 * k))
        }
    }
    
    func computeNative(value: AnyHashable, sort: SortName) -> (k: Int, allocated: Term) {
        return (k: 0, allocated: .Native(value: value, sort: sort))
    }
    
    func computeApp(const: ConstName, count: Int, args: (Int) -> (k: Int, allocated: Term)) -> (k: Int, allocated: Term) {
        var allocatedArgs : [Term] = []
        var k = 0
        for i in 0 ..< count {
            let r = args(i)
            k = max(k, r.k)
            allocatedArgs.append(r.allocated)
        }
        return (k: k, allocated: .App(const: const, args: allocatedArgs))
    }
    
}

class Parsing<Char> {
    
    typealias Param = AnyHashable
    
    typealias Result = ParseTree
    
    private let language : Language
    
    private var g : EarleyLocalLexing.Grammar<L<Char>, S, C<Char>>!
    
    typealias ERule = EarleyLocalLexing.Rule
    
    typealias ESymbol = EarleyLocalLexing.Symbol
    
    private var symbolMap : [SymbolName : ESymbol] = [:]
    private var terminals : [SymbolName] = []
    private var nonterminals : [SymbolName] = []
    
    private var rules : [ERule<Param>] = []
    //private var ruleIds : [RuleId] = []
    
    init(grammar : Grammar, lexers : Lexers<Char>) {
        self.language = grammar.language
        addSymbols(grammar.symbols)
        addRules(grammar.rules)
        let lexer = makeLexer(lexers)
        let priorities = convert(terminalPriorities: grammar.terminalPriorities)
        let selector = S(priorities: priorities)
        let constructResult = C<Char>(terminals: terminals, nonterminals: nonterminals, symbols: grammar.symbols, ruleIds: ruleIds)
        let terminalParseModes = convert(grammar.lookaheads)
        g = EarleyLocalLexing.Grammar(rules: rules, lexer: lexer, selector: selector, constructResult: constructResult, terminalParseModes: terminalParseModes)
    }
    
    private func addSymbols(_ symbols : Grammar.Symbols) {
        for (symbolname, props) in symbols {
            switch props.kind {
            case .nonterminal:
                let index = nonterminals.count
                nonterminals.append(symbolname)
                symbolMap[symbolname] = .nonterminal(index: index)
            case .terminal:
                let index = terminals.count
                terminals.append(symbolname)
                symbolMap[symbolname] = .terminal(index: index)
            }
        }
    }
    
    private func addRules(_ rules : Grammar.Rules) {
        for (_, rules) in rules {
            for rule in rules {
                //ruleIds.append(rule.id)
                self.rules.append(convertRule(rule))
            }
        }
    }
    
    private func convert(_ lookaheads : [SymbolName : Bool]) -> [Int : TerminalParseMode<Param>] {
        var modes :  [Int : TerminalParseMode<Param>] = [:]
        for (symbolname, positive) in lookaheads {
            guard let esymbol = symbolMap[symbolname], case let .terminal(index: index) = esymbol else {
                fatalError("lookahead symbol must be terminal: \(symbolname)")
            }
            let mode : TerminalParseMode<Param>
            if positive {
                mode = .andNext
            } else {
                mode = .notNext(param: UNIT.singleton)
            }
            modes[index] = mode
        }
        return modes
    }
    
    private func convertRule(_ rule : Rule) -> ERule<Param> {
        let lhs = symbolMap[rule.symbol.name]!
        var rhs : [ESymbol] = []
        let store = TermStore()
        let N = rule.rhsCount()
        var conditions : [TermStore.Id] = []
        var inputs : [TermStore.Id?] = Array(repeating: nil, count: N)
        var output : TermStore.Id? = nil
        for bodyElement in rule.body {
            switch bodyElement {
            case let .symbol(symbol: symbol, position: _):
                rhs.append(symbolMap[symbol.name]!)
            case let .assignment(left: left, right: right, position: _):
                let v = SymbolVar.extract(from: left)!
                let k = rule.find(v.symbol)!
                switch v {
                case .In: inputs[k - 1] = store.store(right)
                case .Out: output = store.store(right)
                }
                break
            case let .condition(cond: cond, position: _):
                conditions.append(store.store(cond))
            }
        }
        
        let unit = UNIT.default().inhabitant
        for i in 0 ..< N {
            if inputs[i] == nil {
                inputs[i] = store.store(unit)
            }
        }
        if output == nil {
            output = store.store(unit)
        }
        
        let allocate = Allocate(N: N, findInRule: { n in rule.find(n)! })
        let allocatedStore = TermStore()
        var allocatedInputIds : [TermStore.Id] = []
        for i in 0 ..< N {
            let computed = store.compute(allocate, id: inputs[i]!)
            precondition(computed.k <= i)
            allocatedInputIds.append(allocatedStore.store(computed.allocated))
        }
        let allocatedOutput = store.compute(allocate, id: output!).allocated
        let allocatedOutputId = allocatedStore.store(allocatedOutput)
        
        allocate.output = allocatedOutput
        var allocatedConditionIds : [[TermStore.Id]] = Array(repeating: [], count: N+1)
        for condition in conditions {
            let computed = store.compute(allocate, id: condition)
            allocatedConditionIds[computed.k].append(allocatedStore.store(computed.allocated))
        }
        
        func eval(env: EvalEnv, k: Int, params: [Param]) -> Param? {
            func valueOf(varname : VarName) -> AnyHashable? {
                let index = varname as! Int
                return params[index]
            }
            let computeEnv = Eval(language: language, environment: valueOf)
            for allocatedConditionId in allocatedConditionIds[k] {
                let holds = allocatedStore.compute(computeEnv, id: allocatedConditionId)
                guard holds as! Bool else { return nil }
            }
            let id = (k == N ? allocatedOutputId : allocatedInputIds[k])
            return allocatedStore.compute(computeEnv, id: id)
        }

        return ERule(lhs: lhs, rhs: rhs, initialEnv: E(), eval: eval)
    }
    
    private func makeLexer(_ lexers : Lexers<Char>) -> L<Char> {
        var terminalLexers : [Int : AnyLexer<Char>] = [:]
        for (name, lexer) in lexers.lexers {
            switch symbolMap[name]! {
            case let .terminal(index: index): terminalLexers[index] = lexer
            case .nonterminal: fatalError()
            }
        }
        return L(lexers: terminalLexers)
    }
    
    private func convert(terminalPriorities : Set<TerminalPriority>) -> S.Priorities {
        var priorities : [Int : Set<Int>] = [:]
        func addCondition(_ lower : Int, _ higher : Int) {
            guard var prios = priorities[higher] else {
                priorities[higher] = [lower]
                return
            }
            prios.insert(lower)
            priorities[higher] = prios
        }
        for terminalPriority in terminalPriorities {
            let terminal1 : Int
            switch symbolMap[terminalPriority.terminal1.name]! {
            case let .terminal(index: index): terminal1 = index
            case .nonterminal: fatalError()
            }
            let terminal2 : Int
            switch symbolMap[terminalPriority.terminal2.name]! {
            case let .terminal(index: index): terminal2 = index
            case .nonterminal: fatalError()
            }
            addCondition(terminal1, terminal2)
        }
        return priorities
    }
        
    func parse<In : ASort, Out : ASort>(input : Input<Char>, position : Int, symbol : Symbol<In, Out>, param : In.Native) -> ParseResult<Out.Native> {
        let result = g.parse(input: input, position: position, symbol: symbolMap[symbol.name.name]!, param: param)
        switch result {
        case let .failed(position: position): return .failed(position: position)
        case let .success(length: length, results: results):
            var typedResults : [Out.Native : ParseTree] = [:]
            for (value, result) in results {
                typedResults[value as! Out.Native] = result!
            }
            return .success(length: length, results: typedResults)
        }
    }

}
