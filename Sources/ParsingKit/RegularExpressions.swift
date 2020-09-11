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
    
    public func Repeat(_ symbol : SYMBOL) -> NONTERMINAL {
        let STAR = fresh(nonterminal: SymbolName("\(symbol)*"), in: UNIT(), out: UNIT())
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
    
    public func Repeat1(_ symbol : SYMBOL) -> NONTERMINAL {
        let PLUS = fresh(nonterminal: SymbolName("\(symbol)+"), in : UNIT(), out : UNIT())
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
    
    public func Maybe(_ symbol : SYMBOL) -> NONTERMINAL {
        let MAYBE = fresh(nonterminal: SymbolName("\(symbol)?"), in : UNIT(), out : UNIT())
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
    
    public func Or(_ symbols : SYMBOL...) -> NONTERMINAL {
        let OR = fresh(nonterminal: SymbolName("OR"), in : UNIT(), out : UNIT())
        for symbol in symbols {
            add {
                OR.rule {
                    symbol
                }
            }
        }
        return OR
    }
    
    public func Seq(_ symbols : SYMBOL...) -> NONTERMINAL {
        let SEQ = fresh(nonterminal: SymbolName("SEQ"), in : UNIT(), out : UNIT())
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
