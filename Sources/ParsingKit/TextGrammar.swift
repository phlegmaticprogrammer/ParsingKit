import FirstOrderDeepEmbedding

open class TextGrammar : Grammar {
    
    @Sym public var Char : Terminal<UNIT, CHAR>
    
    public init() {
        super.init()
    }
    
    public func literal(_ chars : String) -> RuleBody {
        var bodies : [RuleBody] = []
        for c in chars {
            let index = TUID()
            let body = collectRuleBody {
                Char[index]
                %?(Char[index]~ == CHAR(c))
            }
            bodies.append(body)
        }
        return collectRuleBody(bodies)
    }
    
    public func const(_ char : Character) -> TERMINAL {
        return const(String(char))
    }

    public func const(_ chars : String) -> TERMINAL {
        let c = fresh(terminal: SymbolName("__const_\(chars)"), in: UNIT(), out: UNIT())
        add {
            c.rule {
                literal(chars)
            }
        }
        return c
    }

    open func parser() -> Parser<Character> {
        let lexers = Lexers<Character>()
        lexers.add(lexer: CharLexer(), for: Char)
        return Parser(grammar: self, lexers: lexers)
    }

}

extension Parser where Char == Character {
    
    public func parse<Out : ASort>(input : String, position : Int = 0, start : Nonterminal<UNIT, Out>) -> ParseResult<Out.Native> {
        return parse(input: ArrayInput(input), position: position, start: start, param: UNIT.singleton)
    }

    public func parse<Out : ASort>(input : ArrayInput<Char>, position : Int = 0, start : Nonterminal<UNIT, Out>) -> ParseResult<Out.Native> {
        return parse(input: input, position: position, start: start, param: UNIT.singleton)
    }

    
}
