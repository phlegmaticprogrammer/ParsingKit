import ParsingKit
import FirstOrderDeepEmbedding


class Regex : Grammar {
    
    @Sym var Char : Terminal<UNIT, CHAR>
    @Sym var A : TERMINAL
    @Sym var B : TERMINAL
    @Sym var C : TERMINAL
    
    var X : NONTERMINAL!
    var Y : NONTERMINAL!
    var Z : NONTERMINAL!
    
    init() {
        super.init()
    }
    
    override func build() {
        add {
            A.rule {
                Char
                %?(Char.out == "A")
            }
            B.rule {
                Char
                %?(Char.out == "B")
            }
            C.rule {
                Char
                %?(Char.out == "C")
            }
        }
        X = Seq(Star(A), B, Maybe(C))
        Y = Seq(Plus(Seq(Or(A, B), C)))
        Z = Seq(B)
    }

}
    
class Simple : Grammar {
    
    @Sym var Char : Terminal<UNIT, CHAR>
    @Sym var A : NONTERMINAL
    
    init() {
        super.init()
    }
    
    override func build() {
        add {
            A.rule {
                Char
                //%?(Char.out == "A")
            }
        }
    }

}
    
