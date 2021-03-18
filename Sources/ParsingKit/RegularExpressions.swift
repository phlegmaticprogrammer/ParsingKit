import FirstOrderDeepEmbedding

extension Grammar {
        
    public func assign<S, T>(_ symbol1 : Symbol<S, T>, _ symbol2 : Symbol<S, T>) -> GrammarElement {
        return symbol1[0].rule {
            symbol2[1]
            symbol2[1] <-- symbol1[0].in
            symbol2[1]~ --> symbol1[0]
        }
    }
    
    public func freshTerminal<S, T>(_ name : String) -> Terminal<S, T> {
        return fresh(terminal: SymbolName(name), in: S(), out: T())
    }
    
    public func freshNonterminal<S, T>(_ name : String) -> Nonterminal<S, T> {
        return fresh(nonterminal: SymbolName(name), in: S(), out:T())
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
        let STAR : Nonterminal<S, S> = freshNonterminal("_Repeat-\(symbol.name.name)")
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
        let STAR : Terminal<S, S> = freshTerminal("_RepeatGreedy-\(symbol.name.name)")
        makeDeep(STAR)
        add {
            assign(STAR, Repeat(symbol))
        }
        return STAR
    }

    public func Iterate<S>(_ symbol : Symbol<S, UNIT>) -> Nonterminal<S, UNIT> {
        let STAR : Nonterminal<S, UNIT> = freshNonterminal("_Iterate-\(symbol.name.name)")
        add {
            STAR.rule {
                EMPTY
            }
            STAR.rule {
                STAR[1]
                symbol
                STAR[1] <-- STAR.in
                symbol <-- STAR.in
            }
        }
        return STAR
    }

    public func IterateGreedy<S>(_ symbol : Symbol<S, UNIT>) -> Symbol<S, UNIT> {
        let STAR : Terminal<S, UNIT> = freshTerminal("_IterateGreedy-\(symbol.name.name)")
        makeDeep(STAR)
        add {
            assign(STAR, Iterate(symbol))
        }
        return STAR
    }

    
    public func Repeat1<S>(_ symbol : Symbol<S, S>) -> Nonterminal<S, S> {
        let PLUS : Nonterminal<S, S> = freshNonterminal("_Repeat1-\(symbol.name.name)")
        add {
            assign(PLUS, symbol)
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
        let PLUS : Terminal<S, S> = freshTerminal("_Repeat1Greedy-\(symbol.name.name)")
        makeDeep(PLUS)
        add {
            assign(PLUS, Repeat1(symbol))
        }
        return PLUS
    }
    
    public func Maybe<S>(_ symbol : Symbol<S, S>) -> Nonterminal<S, S> {
        let MAYBE : Nonterminal<S, S> = freshNonterminal("_Maybe-\(symbol.name.name)")
        add {
            MAYBE.rule {
                EMPTY
                MAYBE.in --> MAYBE
            }
            assign(MAYBE, symbol)
        }
        return MAYBE
    }

    public func MaybeGreedy<S>(_ symbol : Symbol<S, S>) -> Nonterminal<S, S> {
        let MAYBE : Nonterminal<S, S> = freshNonterminal("_MaybeGreedy-\(symbol.name.name)")
        let caseSome : Terminal<S, S> = freshTerminal("_caseSome")
        let caseNone : Terminal<S, S> = freshTerminal("_caseNone")
        add {
            caseNone.rule {
                EMPTY
                caseNone.in --> caseNone
            }
            assign(caseSome, symbol)
            assign(MAYBE, caseSome)
            assign(MAYBE, caseNone)
            prioritise(terminal: caseSome, over: caseNone)
        }
        return MAYBE
    }

    public func MaybeGreedy<S>(_ symbol : Symbol<S, UNIT>) -> Nonterminal<S, UNIT> {
        let MAYBE : Nonterminal<S, UNIT> = freshNonterminal("_MaybeGreedy-\(symbol.name.name)")
        let caseSome : Terminal<S, UNIT> = freshTerminal("_caseSome")
        let caseNone : Terminal<S, UNIT> = freshTerminal("_caseNone")
        add {
            caseNone.rule {
                EMPTY
            }
            assign(caseSome, symbol)
            assign(MAYBE, caseSome)
            assign(MAYBE, caseNone)
            prioritise(terminal: caseSome, over: caseNone)
        }
        return MAYBE
    }
    
    public func Or<S, T>(_ symbols : Symbol<S, T>...) -> Nonterminal<S, T> {
        let OR : Nonterminal<S, T> = freshNonterminal("_Or")
        for symbol in symbols {
            add {
                assign(OR, symbol)
            }
        }
        return OR
    }
    
    public func OrGreedy<S, T>(_ symbols : Symbol<S, T>...) -> Nonterminal<S, T> {
        let OR : Nonterminal<S, T> = freshNonterminal("_OrGreedy")
        var i = 1
        var higher : [Terminal<S, T>] = []
        for symbol in symbols {
            let terminal : Terminal<S, T> = freshTerminal("_case-\(i)")
            makeDeep(terminal)
            for h in higher {
                add {
                    prioritise(terminal: h, over: terminal)
                }
            }
            add {
                assign(OR, terminal)
                assign(terminal, symbol)
            }
            i += 1
            higher.append(terminal)
        }
        return OR
    }
    
    public func Seq<S, U, V>(_ symbol1 : Symbol<S, U>, _ symbol2 : Symbol<U, V>) -> Nonterminal<S, V> {
        let SEQ : Nonterminal<S, V> = freshNonterminal("_Seq")
        let index1 = TUID()
        let index2 = TUID()
        add {
            SEQ.rule {
                symbol1[index1]
                symbol2[index2]
                symbol1[index1] <-- SEQ.in
                symbol2[index2] <-- symbol1[index1]~
                symbol2[index2]~ --> SEQ
            }
        }
        return SEQ
    }

    public func Seq<S, U, V, W>(_ symbol1 : Symbol<S, U>, _ symbol2 : Symbol<U, V>, _ symbol3 : Symbol<V, W>) -> Nonterminal<S, W> {
        let SEQ : Nonterminal<S, W> = freshNonterminal("_Seq")
        let index1 = TUID()
        let index2 = TUID()
        let index3 = TUID()
        add {
            SEQ.rule {
                symbol1[index1]
                symbol2[index2]
                symbol3[index3]
                symbol1[index1] <-- SEQ.in
                symbol2[index2] <-- symbol1[index1]~
                symbol3[index3] <-- symbol2[index2]~
                symbol3[index3]~ --> SEQ
            }
        }
        return SEQ
    }

    public func Seq<S, U, V, W, X>(_ symbol1 : Symbol<S, U>, _ symbol2 : Symbol<U, V>, _ symbol3 : Symbol<V, W>,
                                   _ symbol4 : Symbol<W, X>) -> Nonterminal<S, X> {
        let SEQ : Nonterminal<S, X> = freshNonterminal("_Seq")
        let index1 = TUID()
        let index2 = TUID()
        let index3 = TUID()
        let index4 = TUID()
        add {
            SEQ.rule {
                symbol1[index1]
                symbol2[index2]
                symbol3[index3]
                symbol4[index4]
                symbol1[index1] <-- SEQ.in
                symbol2[index2] <-- symbol1[index1]~
                symbol3[index3] <-- symbol2[index2]~
                symbol4[index4] <-- symbol3[index3]~
                symbol4[index4]~ --> SEQ
            }
        }
        return SEQ
    }

    public func Seq<S, U, V, W, X, Y>(_ symbol1 : Symbol<S, U>, _ symbol2 : Symbol<U, V>, _ symbol3 : Symbol<V, W>,
                                      _ symbol4 : Symbol<W, X>, _ symbol5 : Symbol<X, Y>) -> Nonterminal<S, Y> {
        let SEQ : Nonterminal<S, Y> = freshNonterminal("_Seq")
        let index1 = TUID()
        let index2 = TUID()
        let index3 = TUID()
        let index4 = TUID()
        let index5 = TUID()
        add {
            SEQ.rule {
                symbol1[index1]
                symbol2[index2]
                symbol3[index3]
                symbol4[index4]
                symbol5[index5]
                symbol1[index1] <-- SEQ.in
                symbol2[index2] <-- symbol1[index1]~
                symbol3[index3] <-- symbol2[index2]~
                symbol4[index4] <-- symbol3[index3]~
                symbol5[index5] <-- symbol4[index4]~
                symbol5[index5]~ --> SEQ
            }
        }
        return SEQ
    }
        
    public func Supply<S, T>(_ input : S = S.default(), _ symbol : Symbol<S, T>) -> Nonterminal<UNIT, T> {
        let s : Nonterminal<UNIT, T> = freshNonterminal("_Supply-\(symbol.name.name)")
        add {
            s.rule {
                symbol
                symbol <-- input
                symbol~ --> s
            }
        }
        return s
    }
    
    public func Greedy<S, T>(_ symbol : Symbol<S, T>) -> Terminal<S, T> {
        let g : Terminal<S, T> = freshTerminal("_Greedy-\(symbol.name.name)")
        makeDeep(g)
        add {
            assign(g, symbol)
        }
        return g
    }

}
