import FirstOrderDeepEmbedding

extension Grammar {
    
    public typealias SYMBOL = Symbol<UNIT, UNIT>
    
    public func assign(_ symbol1 : SYMBOL, _ symbol2 : SYMBOL) -> GrammarElement {
        return symbol1.rule {
            symbol2
        }
    }
    
    public func freshTERMINAL(_ name : String) -> TERMINAL {
        return fresh(terminal: SymbolName(name))
    }
    
    public func freshNONTERMINAL(_ name : String) -> NONTERMINAL {
        return fresh(nonterminal: SymbolName(name), in: UNIT(), out:UNIT())
    }
    
    public func Empty() -> NONTERMINAL {
        let E = freshNONTERMINAL("__Empty")
        add {
            E.rule {
                EMPTY
            }
        }
        return E
    }
    
    public func Repeat(_ symbol : SYMBOL) -> NONTERMINAL {
        let STAR = freshNONTERMINAL("_Repeat")
        add {
            STAR.rule {
                EMPTY
            }
            STAR.rule {
                STAR[1]
                symbol
            }
        }
        return STAR
    }

    public func RepeatGreedy(_ symbol : SYMBOL) -> SYMBOL {
        let STAR = freshTERMINAL("_RepeatGreedy")
        makeDeep(STAR)
        add {
            assign(STAR, Repeat(symbol))
        }
        return STAR
    }
    
    public func Repeat1(_ symbol : SYMBOL) -> NONTERMINAL {
        let PLUS = freshNONTERMINAL("_Repeat1")
        add {
            PLUS.rule {
                symbol
            }
            PLUS.rule {
                PLUS[1]
                symbol
            }
        }
        return PLUS
    }
    
    public func Repeat1Greedy(_ symbol : SYMBOL) -> SYMBOL {
        let PLUS = freshTERMINAL("_Repeat1Greedy")
        makeDeep(PLUS)
        add {
            assign(PLUS, Repeat1(symbol))
        }
        return PLUS
    }
    
    public func Maybe(_ symbol : SYMBOL) -> NONTERMINAL {
        let MAYBE = freshNONTERMINAL("_Maybe")
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
        let MAYBE = freshNONTERMINAL("_MaybeGreedy")
        let caseSome = freshTERMINAL("_caseSome")
        let caseNone = freshTERMINAL("_caseNone")
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
        let OR = freshNONTERMINAL("_Or")
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
        let OR = freshNONTERMINAL("_OrGreedy")
        var i = 1
        var higher : [TERMINAL] = []
        for symbol in symbols {
            let terminal = freshTERMINAL("_case-\(i)")
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
        let SEQ = freshNONTERMINAL("_Seq")
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
