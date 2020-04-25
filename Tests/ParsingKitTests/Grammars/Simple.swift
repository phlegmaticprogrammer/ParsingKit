import ParsingKit
import FirstOrderDeepEmbedding

class Simple : TextGrammar {
    
    @Sym var A : NONTERMINAL
        
    override func build() {
        add {
            A.rule {
                Char
                %?(Char~ == "A")
            }
        }
    }

}
 
