import ParsingKit
import FirstOrderDeepEmbedding

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
                %?(Char.out == "A")
            }
        }
    }

}
 
