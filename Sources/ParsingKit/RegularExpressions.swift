import FirstOrderDeepEmbedding

extension Grammar {
    
    public typealias SYMBOL = Symbol<UNIT, UNIT>
    
    public func assign<S, T>(_ symbol1 : Symbol<S, T>, _ symbol2 : Symbol<S, T>) -> GrammarElement {
        return symbol1.rule {
            symbol2
            symbol2 <-- symbol1.in
            symbol2~ --> symbol1
        }
    }
    
    public func freshTerminal<S>(_ name : String) -> Terminal<S, S> {
        return fresh(terminal: SymbolName(name), in: S(), out: S())
    }
    
    public func freshNonterminal<S>(_ name : String) -> Nonterminal<S, S> {
        return fresh(nonterminal: SymbolName(name), in: S(), out:S())
    }
    
    public func Empty<S>() -> Nonterminal<S, S> {
        let E : Nonterminal<S, S> = freshNonterminal("__Empty")
        add {
            E.rule {
                EMPTY
                E.in --> E
            }
        }
        return E
    }
    
    public func Repeat<S>(_ symbol : Symbol<S, S>) -> Nonterminal<S, S> {
        let STAR : Nonterminal<S, S> = freshNonterminal("_Repeat")
        add {
            STAR.rule {
                EMPTY
                STAR.in --> STAR
            }
            STAR.rule {
                STAR[1]
                symbol
                STAR[1] <-- STAR.in
                symbol <-- STAR[1]~
                symbol~ --> STAR
            }
        }
        return STAR
    }

    public func RepeatGreedy<S>(_ symbol : Symbol<S, S>) -> Symbol<S, S> {
        let STAR : Terminal<S, S> = freshTerminal("_RepeatGreedy")
        makeDeep(STAR)
        add {
            assign(STAR, Repeat(symbol))
        }
        return STAR
    }
    
    public func Repeat1<S>(_ symbol : Symbol<S, S>) -> Nonterminal<S, S> {
        let PLUS : Nonterminal<S, S> = freshNonterminal("_Repeat1")
        add {
            PLUS.rule {
                symbol
                symbol <-- PLUS.in
                symbol~ --> PLUS
            }
            PLUS.rule {
                PLUS[1]
                symbol
                PLUS[1] <-- PLUS.in
                symbol <-- PLUS[1]~
                symbol~ --> PLUS
            }
        }
        return PLUS
    }
    
    public func Repeat1Greedy<S>(_ symbol : Symbol<S, S>) -> Symbol<S,S> {
        let PLUS : Terminal<S, S> = freshTerminal("_Repeat1Greedy")
        makeDeep(PLUS)
        add {
            assign(PLUS, Repeat1(symbol))
        }
        return PLUS
    }
    
    public func Maybe(_ symbol : SYMBOL) -> NONTERMINAL {
        let MAYBE : NONTERMINAL = freshNonterminal("_Maybe")
        add {
            MAYBE.rule {
                EMPTY
            }
            MAYBE.rule {
                symbol
            }
        }
        return MAYBE
    }

    public func MaybeGreedy(_ symbol : SYMBOL) -> NONTERMINAL {
        let MAYBE : NONTERMINAL = freshNonterminal("_MaybeGreedy")
        let caseSome : TERMINAL = freshTerminal("_caseSome")
        let caseNone : TERMINAL = freshTerminal("_caseNone")
        add {
            caseNone.rule {
                EMPTY
            }
            caseSome.rule {
                symbol
            }
            MAYBE.rule {
                caseSome
            }
            MAYBE.rule {
                caseNone
            }
            prioritise(terminal: caseSome, over: caseNone)
        }
        return MAYBE
    }

    public func Or(_ symbols : SYMBOL...) -> NONTERMINAL {
        let OR : NONTERMINAL = freshNonterminal("_Or")
        for symbol in symbols {
            add {
                OR.rule {
                    symbol
                }
            }
        }
        return OR
    }
    
    public func OrGreedy(_ symbols : SYMBOL...) -> SYMBOL {
        let OR : NONTERMINAL = freshNonterminal("_OrGreedy")
        var i = 1
        var higher : [TERMINAL] = []
        for symbol in symbols {
            let terminal : TERMINAL = freshTerminal("_case-\(i)")
            makeDeep(terminal)
            for h in higher {
                add {
                    prioritise(terminal: h, over: terminal)
                }
            }
            add {
                OR.rule {
                    terminal
                }
                terminal.rule {
                    symbol
                }
            }
            i += 1
            higher.append(terminal)
        }
        return OR
    }
    
    public func Seq(_ symbols : SYMBOL...) -> NONTERMINAL {
        let SEQ : NONTERMINAL = freshNonterminal("_Seq")
        var bodies : [RuleBody] = []
        for symbol in symbols {
            let index = TUID()
            bodies.append(collectRuleBody {
                symbol[index]
            })
        }
        add {
            SEQ.rule {
                collectRuleBody(bodies)
            }
        }
        return SEQ
    }

}
