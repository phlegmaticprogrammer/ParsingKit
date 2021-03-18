import FirstOrderDeepEmbedding

public enum GrammarComponent {
    
    case rule(rule : Rule)
    
    case terminalPriority(priority : TerminalPriority)
    
    var position : Position {
        switch self {
        case let .rule(r): return r.position
        case let .terminalPriority(priority: priority): return priority.position
        }
    }
}

public protocol GrammarElement {
    func grammarComponents() -> [GrammarComponent]
}

internal struct GrammarElements : GrammarElement {
    var _grammarComponents : [GrammarComponent]
    mutating func add(_ impl : GrammarElement) {
        _grammarComponents.append(contentsOf: impl.grammarComponents())
    }
    func grammarComponents() -> [GrammarComponent] {
        return _grammarComponents
    }
    static func empty() -> GrammarElements {
        return GrammarElements(_grammarComponents: [])
    }
}

@_functionBuilder
public class GrammarBuilder {
    
    public static func buildBlock(_ components : GrammarElement...) -> GrammarElement  {
        var elements = GrammarElements.empty()
        for c in components {
            elements.add(c)
        }
        return elements
    }
    
    public static func buildIf(_ component : GrammarElement?) -> GrammarElement {
        return component ?? GrammarElements.empty()
    }

}

public func collectGrammarElement(_ elements : [GrammarElement]) -> GrammarElement {
    var components : [GrammarComponent] = []
    for elem in elements {
        components.append(contentsOf: elem.grammarComponents())
    }
    return GrammarElements(_grammarComponents: components)
}

public func collectGrammarElement(@GrammarBuilder _ grammarBuilder : () -> GrammarElement) -> GrammarElement
{
    return grammarBuilder()
}

internal protocol SettableSymbol {
    func setSymbol(grammar : Grammar, name : SymbolName)
}

open class Grammar {
    
    public enum Visibility : Hashable {
        case Auxiliary
        case Visible
    }
    
    public enum Structure : Hashable {
        case Flat
        case Deep
    }
    
    public enum Availability : Hashable {
        case Private
        case Public
        case Open
    }
    
    public struct Properties : Hashable {
        public let visibility : Visibility
        public let structure : Structure
        public let availability : Availability
        public let kind : SymbolKind
        
        func makeFlat() -> Properties {
            return Properties(visibility: visibility, structure: .Flat, availability: availability, kind: kind)
        }

        func makeDeep() -> Properties {
            return Properties(visibility: visibility, structure: .Deep, availability: availability, kind: kind)
        }
        
        public var isHidden : Bool {
            return visibility == .Auxiliary && structure == .Flat
        }

    }
    
    @propertyWrapper
    public class Sym<In : Sort, Out : Sort, S : Symbol<In, Out>> : SettableSymbol {
        
        private var symbol : S? = nil
        
        public init() {}
        
        public var wrappedValue : S {
            return symbol!
        }
        
        internal func setSymbol(grammar : Grammar, name : SymbolName) {
            let provisionalSym = S(name: IndexedSymbolName(name))
            let (symbolName, properties) = grammar.defaultProperties(name: name, kind: provisionalSym.kind)
            let sym = S(name: IndexedSymbolName(symbolName))
            precondition(grammar.install(symbol: sym, properties: properties))
            self.symbol = sym
        }
    }

    public typealias Symbols = [SymbolName : Properties]
    
    public typealias Rules = [SymbolName : Set<Rule>]
    
    private var _symbols : Symbols
        
    private var _lookaheadSymbols : [SymbolName : Bool]
    
    private var _rules : Rules
    
    private var _terminalPriorities : Set<TerminalPriority>
        
    private var _language : Language

    private var _sealed : Bool
        
    public var language : Language {
        return _language
    }
    
    public var symbols : Symbols {
        return _symbols
    }
        
    public var rules : Rules {
        return _rules
    }
    
    public func rulesOf(symbol : SymbolName) -> Set<Rule> {
        return _rules[symbol] ?? []
    }
    
    public var terminalPriorities : Set<TerminalPriority> {
        return _terminalPriorities
    }
    
    public var lookaheads :  [SymbolName : Bool] {
        return _lookaheadSymbols
    }
        
    private static func add(symbols : inout Symbols, moreSymbols : Symbols) {
        for (name, props) in moreSymbols {
            if let oldProps = symbols[name] {
                if oldProps != props { fatalError("conflicting declaration of symbol \(name)") }
            } else {
                symbols[name] = props
            }
        }
    }
    
    private static func add(rules : inout Rules, moreRules : Rules) {
        for (name, ruleSet) in moreRules {
            if rules[name] != nil {
                rules[name]!.formUnion(ruleSet)
            } else {
                rules[name] = ruleSet
            }
        }
    }
    
    public init(parents : [Grammar] = [], sealed : Bool = true) {
        guard parents.count <= 1 else {
            fatalError("no multiple inheritance allowed")
        }
        var symbols : Symbols = [:]
        var rules : Rules = [:]
        var priorities : Set<TerminalPriority> = []
        var lookaheads : [SymbolName : Bool] = [:]
        var l = Language.standard
        for parent in parents {
            if !parent.isSealed { fatalError("grammar parents must be sealed") }
            for (lookahead, mode) in parent._lookaheadSymbols {
                if symbols[lookahead] != nil {
                    guard let currentMode = lookaheads[lookahead], currentMode == mode else {
                        fatalError("incompatible lookaheads in parents found")
                    }
                } else {
                    lookaheads[lookahead] = mode
                }
            }
            Grammar.add(symbols: &symbols, moreSymbols: parent._symbols)
            Grammar.add(rules: &rules, moreRules: parent._rules)
            priorities.formUnion(parent._terminalPriorities)
            l = Language.join(l, parent.language)
        }
        self._language = l
        self._symbols = symbols
        self._rules = rules
        self._terminalPriorities = priorities
        self._sealed = false
        self._lookaheadSymbols = lookaheads
        installPropertySymbols(mirror : Mirror(reflecting: self))
        build()
        if sealed { seal() }
    }
    
    private func extractPropertyName(_ name : String) -> String? {
        guard name.first == "_" else { return nil }
        return String(name.dropFirst())
    }
    
    private func installPropertySymbols(mirror : Mirror) {
        if let parent = mirror.superclassMirror {
            installPropertySymbols(mirror: parent)
        }
        for child in mirror.children {
            if let x = child.value as? SettableSymbol {
                let name = extractPropertyName(child.label!)!
                x.setSymbol(grammar: self, name: SymbolName(name))
            }
        }
    }
    
    public var isSealed : Bool {
        get {
            return _sealed
        }
    }
    
    public func seal() {
        guard !_sealed else { return }
        _sealed = true
        checkGrammar()
    }
    
    private func checkSeal() {
        if isSealed { fatalError("grammar is already sealed, cannot modify") }
    }
    
    public func kindOf(_ name : SymbolName) -> SymbolKind? {
        return _symbols[name]?.kind
    }
    
    public func propertiesOf(_ name : SymbolName) -> Properties? {
        return _symbols[name]
    }

    public func exists(_ name : SymbolName) -> Bool {
        return _symbols[name] != nil
    }
    
    public func isDeep(_ name : SymbolName) -> Bool {
        guard let props = _symbols[name] else { return false }
        return props.structure == .Deep
    }
    
    public func isFlat(_ name : SymbolName) -> Bool {
        guard let props = _symbols[name] else { return false }
        return props.structure == .Flat
    }
    
    public func isVisible(_ name : SymbolName) -> Bool {
        guard let props = _symbols[name] else { return false }
        return props.visibility == .Visible
    }

    public func isAuxiliary(_ name : SymbolName) -> Bool {
        guard let props = _symbols[name] else { return false }
        return props.visibility == .Auxiliary
    }

    public func isHidden(_ name : SymbolName) -> Bool {
        guard let props = _symbols[name] else { return false }
        return props.isHidden
    }
    
    public func makeFlat(_ name : SymbolName) {
        checkSeal()
        precondition(exists(name))
        _symbols[name] = _symbols[name]!.makeFlat()
    }
    
    private func makeDeep(_ name : SymbolName) {
        checkSeal()
        precondition(exists(name))
        _symbols[name] = _symbols[name]!.makeDeep()
    }
    
    public func makeDeep<I,O>(_ terminal : Terminal<I, O>) {
        self.makeDeep(terminal.name.name)
    }
        
    private func freshSymbol(basedOn : SymbolName) -> SymbolName {
        let base = stripName(name: basedOn)
        guard _symbols[base] != nil else { return basedOn }
        for i in 0 ... Int.max {
            let name = SymbolName("\(base)-\(i)")
            if _symbols[name] == nil { return SymbolName("\(basedOn)-\(i)") }
        }
        fatalError("could not create fresh symbol based on '\(basedOn)'")
    }
    
    public func install(sort : Sort) {
        guard !_language.isValid(sort: sort.sortname) else { return }
        checkSeal()
        _language.add(sort: sort)
    }
    
    private func stripName(name : SymbolName) -> SymbolName {
        let n = name.name
        if n.hasPrefix("__") {
            return SymbolName(String(n.dropFirst(2)))
        } else if n.hasPrefix("_") {
            return SymbolName(String(n.dropFirst()))
        } else {
            return name
        }
    }
    
    private func defaultProperties(name : SymbolName, kind : SymbolKind) -> (SymbolName, Properties) {
        var n = name.name
        let visibility : Grammar.Visibility
        var structure : Grammar.Structure = kind.isNonterminal ? .Deep : .Flat
        if n.hasPrefix("__") {
            n = String(n.dropFirst(2))
            visibility = .Auxiliary
            structure = .Flat
        } else if n.hasPrefix("_") {
            n = String(n.dropFirst())
            visibility = .Auxiliary
        } else {
            visibility = .Visible
        }
        let availability : Grammar.Availability = .Open
        let properties = Properties(visibility: visibility, structure: structure, availability: availability, kind: kind)
        return (SymbolName(n), properties)
    }
    
    public func install<In : Sort, Out : Sort>(symbol : Symbol<In, Out>, properties : Grammar.Properties) -> Bool {
        guard !symbol.name.name.name.hasPrefix("_") else {
            fatalError("symbol name cannot start with underscore: \(symbol.name)")
        }
        let name = symbol.name.name
        if let existing = _symbols[name] {
            return existing == properties
        } else {
            checkSeal()
            let kind = symbol.kind
            install(sort: kind.in)
            install(sort: kind.out)
            _symbols[name] = properties
            return true
        }
    }
    
    public func terminal<In : Sort, Out : Sort>(_ name : SymbolName, in : In = In(), out : Out = Out()) -> Terminal<In, Out> {
        let (symbolName, properties) = defaultProperties(name: name, kind: .terminal(in: `in`, out: out))
        let symbol = Terminal<In, Out>(name: IndexedSymbolName(symbolName), kind: properties.kind)
        precondition(install(symbol: symbol, properties: properties))
        return symbol
    }
    
    public func terminal<In : Sort>(_ name : SymbolName, in : In = In()) -> Terminal<In, UNIT> {
        terminal(name, in: `in`, out: UNIT.default())
    }
    
    public func terminal<Out : Sort>(_ name : SymbolName, out : Out = Out()) -> Terminal<UNIT, Out> {
        terminal(name, in: UNIT.default(), out: out)
    }
    
    public func terminal(_ name : SymbolName) -> Terminal<UNIT, UNIT> {
        terminal(name, in: UNIT.default(), out: UNIT.default())
    }
    
    public func fresh<In : Sort, Out : Sort>(terminal name : SymbolName, in : In = In(), out : Out = Out()) -> Terminal<In, Out> {
        return terminal(freshSymbol(basedOn: name), in: `in`, out: out)
    }
    
    public func nonterminal<In : Sort, Out : Sort>(_ name : SymbolName, in : In = In(), out : Out = Out()) -> Nonterminal<In, Out> {
        let (symbolName, properties) = defaultProperties(name: name, kind: .nonterminal(in: `in`, out: out))
        let symbol = Nonterminal<In, Out>(name: IndexedSymbolName(symbolName), kind: properties.kind)
        precondition(install(symbol: symbol, properties: properties))
        return symbol
    }
    
    public func nonterminal<In : Sort>(_ name : SymbolName, in : In = In()) -> Nonterminal<In, UNIT> {
        nonterminal(name, in: `in`, out: UNIT.default())
    }
    
    public func nonterminal<Out : Sort>(_ name : SymbolName, out : Out = Out()) -> Nonterminal<UNIT, Out> {
        nonterminal(name, in: UNIT.default(), out: out)
    }
    
    public func nonterminal(_ name : SymbolName) -> Nonterminal<UNIT, UNIT> {
        nonterminal(name, in: UNIT.default(), out: UNIT.default())
    }

    public func fresh<In : Sort, Out : Sort>(nonterminal name : SymbolName, in : In, out : Out) -> Nonterminal<In, Out> {
        return nonterminal(freshSymbol(basedOn: name), in: `in`, out: out)
    }
    
    public var EMPTY : RuleBody {
        return RuleBodyImpl(ruleBodyElems: [])
    }

    public func prioritise<In1 : Sort, Out1 : Sort, In2 : Sort, Out2 : Sort>(
        terminal terminal2 : Terminal<In1, Out1>,
        over terminal1 : Terminal<In2, Out2>,
        file : String = #file, line : Int = #line) -> TerminalPriority
    {
        return TerminalPriority(position: .position(file: file, line: line),
                                terminal1: terminal1.name, terminal2: terminal2.name)
    }
    
    public func prioritise<In1 : ASort, Out1 : ASort, In2 : ASort, Out2 : ASort>(
        terminal terminal2 : Terminal<In1, Out1>,
        over terminal1 : Terminal<In2, Out2>,
        if : @escaping (In1.Native, Out1.Native, Int, In2.Native, Out2.Native, Int) -> Bool,
        file : String = #file, line : Int = #line) -> TerminalPriority
    {
        func w(lower : TerminalPriority.Attributes, upper : TerminalPriority.Attributes) -> Bool {
            let in1 = upper.paramIn as! In1.Native
            let out1 = upper.paramOut as! Out1.Native
            let len1 = upper.length
            let in2 = lower.paramIn as! In2.Native
            let out2 = lower.paramOut as! Out2.Native
            let len2 = lower.length
            return `if`(in1, out1, len1, in2, out2, len2)
        }
        return TerminalPriority(position: .position(file: file, line: line),
                                terminal1: terminal1.name, terminal2: terminal2.name,
                                when: w)
    }

    // Do not provide a lexer for the terminal returned here!!!
    public func andNext<In : Sort, Out : Sort>(_ symbol : Symbol<In, Out>) -> Terminal<In, Out> {
        let name = SymbolName("_andNext-\(symbol.name.name)")
        let terminal : Terminal<In, Out> = fresh(terminal: name)
        makeDeep(terminal)
        add {
            terminal.rule {
                symbol
                symbol <-- terminal.in
                symbol~ --> terminal
            }
        }
        _lookaheadSymbols[terminal.name.name] = true
        return terminal
    }
    
    // Do not provide a lexer for the terminal returned here!!!
    public func notNext<In : Sort, Out : Sort>(_ symbol : Symbol<In, Out>) -> Terminal<In, UNIT> {
        let name = SymbolName("_notNext-\(symbol.name.name)")
        let terminal : Terminal<In, UNIT> = fresh(terminal: name)
        makeDeep(terminal)
        add {
            terminal.rule {
                symbol
                symbol <-- terminal.in
            }
        }
        _lookaheadSymbols[terminal.name.name] = false
        return terminal
    }

    public func add(@GrammarBuilder _ builder : () -> GrammarElement) {
        let components = builder().grammarComponents()
        for component in components {
            add(component: component)
        }
    }
    
    public func add(component : GrammarComponent) {
        switch component {
        case let .rule(rule: r): add(rule: r)
        case let .terminalPriority(priority: priority): add(terminalPriority: priority)
        }
    }
    
    private func failedCheck(_ position : HasPosition = Position.unknown, _ message : String? = nil) -> Never {
        let p : String
        if case let .position(file: file, line: line) = position.position {
            p = "(line \(line) in file '\(file)')"
        } else {
            p = ""
        }
        if message != nil {
            fatalError("\(message!) \(p)")
        } else {
            fatalError("failed check \(p)")
        }
    }
        
    private func check(_ position : HasPosition = Position.unknown, symbol : IndexedSymbolName) {
        guard exists(symbol.name) else { failedCheck(position, "no symbol \(symbol) declared in grammar") }
    }
    
    @discardableResult
    private func check(position _position : HasPosition = Position.unknown, _ stack : RuleStack, term : Term) -> (sortname: SortName, id: TermStore.Id) {
        let position = _position.otherwise(stack.rule)
        let termId = stack.termStore.store(term)
        let computation = SortOf(language: language, environment: stack.typingEnvironment(grammar: self))
        guard let sortname = stack.termStore.compute(computation, id: termId) else {
            failedCheck(position, "cannot typecheck '\(term)'")
        }
        return (sortname: sortname, id: termId)
    }
        
    private func check(_ stack : inout RuleStack, elem : RuleBodyElem) {
        let position = elem.otherwise(stack.rule)
        switch elem {
        case let .symbol(symbol: symbol, position: _):
            check(stack.rule, symbol: symbol)
            guard stack.appendSymbol(symbol) else { failedCheck(position, "symbol \(symbol) has already been introduced") }
        case let .condition(cond: cond, position: _):
            let bool = BOOL().sortname
            let checked = check(position: position, stack, term: cond).sortname
            guard bool == checked else {
                failedCheck(position, "condition must have sort '\(bool)' but has sort '\(checked)': \(cond)")
            }
        case let .assignment(left: left, right: right, position: _):
            let lc = check(position: position, stack, term: left).sortname
            let rc = check(position: position, stack, term: right).sortname
            guard lc == rc else {
                failedCheck(position, "left and right hand side of assignment have different sorts '\(lc)' and '\(rc)'")
            }
            guard let leftVar = SymbolVar.extract(from: left) else {
                failedCheck(position, "expected in/out variable on left hand side of rule, but found: \(left)")
            }
            guard stack.assign(leftVar) else {
                failedCheck(position, "cannot assign to variable '\(leftVar)' here")
            }
            let allowedVars = stack.allowedSymbolsInAssignmentTo(leftVar.symbol)
            let containedVars = stack.termStore.compute(VarNamesOf(), id: stack.store(right))
            for containedVar in containedVars {
                guard let v = containedVar as? SymbolVar, allowedVars.contains(v) else {
                    failedCheck(position, "cannot use '\(containedVar)' in assignment to '\(leftVar)'")
                }
            }
        }
    }
    
    private func checkRuleCompleteness(_ stack : RuleStack) {
        let rule = stack.rule
        let missing = stack.missingAssignments()
        let unit = UNIT().sortname
        for symbol in missing.ins {
            if kindOf(symbol.name)!.in.sortname != unit {
                failedCheck(rule, "missing input assignment for symbol \(symbol)")
            }
        }
        if missing.out {
            if kindOf(rule.symbol.name)!.out.sortname != unit {
                failedCheck(rule, "missing output assignment for symbol \(rule.symbol)")
            }
        }
    }
    
    @discardableResult
    private func check(rule : Rule) -> RuleStack {
        guard !rule.symbol.hasIndex else { failedCheck(rule, "symbol \(rule.symbol) on left hand side of rule has index") }
        check(rule, symbol: rule.symbol)
        var stack = RuleStack(rule: rule, lhs: rule.symbol, store: TermStore())
        for elem in rule.body {
            check(&stack, elem : elem)
        }
        checkRuleCompleteness(stack)
        return stack
    }
    
    private func add(rule : Rule) {
        checkSeal()
        rule.id.set(id: _rules.count)
        check(rule: rule)
        let name = rule.symbol.name
        if _rules[name] != nil {
            _rules[name]!.insert(rule)
        } else {
            _rules[name] = [rule]
        }
    }
    
    private func add(terminalPriority : TerminalPriority) {
        checkSeal()
        guard let kind1 = kindOf(terminalPriority.terminal1.name), kind1.isTerminal else {
            failedCheck(terminalPriority, "Terminal '\(terminalPriority.terminal1)' does not exist in grammar.")
        }
        guard let kind2 = kindOf(terminalPriority.terminal2.name), kind2.isTerminal else {
            failedCheck(terminalPriority, "Terminal '\(terminalPriority.terminal2)' does not exist in grammar.")
        }
        guard terminalPriority.terminal1 != terminalPriority.terminal2 else {
            failedCheck(terminalPriority, "Symbols '\(terminalPriority.terminal1)' are identical, must be distinguished.")
        }
        _terminalPriorities.insert(terminalPriority)
    }
    
    open func build() { }
    
    // computes the symbols the right hand side of this rule depends on, assuming wellformedness of rule
    private func symbolDependencies(rule : Rule) -> Set<SymbolName> {
        var names : Set<SymbolName> = []
        for e in rule.body {
            switch e {
            case .assignment, .condition: break
            case .symbol(symbol: let symbol, position: _):
                names.insert(symbol.name)
            }
        }
        return names
    }
    
    private func computeSymbolDependencies() -> [SymbolName : Set<SymbolName>] {
        var dependencies : [SymbolName : Set<SymbolName>] = [:]
        for (symbol, rules) in rules {
            var deps : Set<SymbolName> = []
            for rule in rules {
                let ds = symbolDependencies(rule: rule)
                deps.formUnion(ds)
            }
            dependencies[symbol] = deps
        }
        var changed : Bool
        repeat {
            changed = false
            for (symbol, deps) in dependencies {
                var symbolDeps = deps
                let oldCount = symbolDeps.count
                for dep in deps {
                    if let ds = dependencies[dep] {
                        symbolDeps.formUnion(ds)
                    }
                }
                if symbolDeps.count != oldCount {
                    changed = true
                }
                dependencies[symbol] = symbolDeps
            }
        } while changed
        return dependencies
    }
    
    private func checkGrammar() {
        /*let dependencies = computeSymbolDependencies()
        for (symbol, deps) in dependencies {
            if kindOf(symbol)!.isTerminal && deps.contains(symbol) {
                print("warning: terminal '\(symbol)' depends on itself")
                //failedCheck(Position.unknown, "terminal '\(symbol)' depends on itself")
            }
        }*/
        for (symbol, rulesOfSymbol) in rules {
            var names : Set<String> = []
            for rule in rulesOfSymbol {
                if !rule.name.isAnonymous {
                    if !names.insert(rule.name.name!).inserted {
                        failedCheck(rule, "rule has duplicate name '\(rule.name.name!)' for symbol '\(symbol)'")
                    }
                }
            }
        }
    }

}
