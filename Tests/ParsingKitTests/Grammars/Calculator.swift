import ParsingKit
import FirstOrderDeepEmbedding


class Calculator : TextGrammar {
    
    typealias N = Nonterminal<UNIT, INT>
    
    @Sym var Expr : N
    @Sym var Sum : N
    @Sym var Product : N
    @Sym var Num : N
    @Sym var Digit : N
        
    let ambiguous : Bool
    
    init(ambiguous : Bool) {
        self.ambiguous = ambiguous
    }
    
    override func build() {
        add {
            Expr.rule {
                Sum
                                
                Sum.out --> Expr
            }

            Sum.rule {
                Sum[1]
                literal("+")
                Product
                
                Sum[1]~ + Product~ --> Sum
            }

            Sum.rule {
                Product
                                
                Product~ --> Sum
            }

            Product.rule {
                Product[1]
                literal("*")
                Num
                
                Product[1]~ * Num~ --> Product
            }
            
            Product.rule {
                Num

                Num~ --> Product
            }
            
            Num.rule {
                Digit
                
                Digit~ --> Num
            }
            
            
            if !ambiguous {
                Num.rule {
                    Num[1]
                    Digit
                                        
                    Num[1]~ * 10 + Digit~ --> Num
                }
            }
            
            if ambiguous {
                Num.rule {
                    Num[1]
                    Num[2]
                                        
                    Num[1]~ * 10 + Num[2]~ --> Num
                }
            }
            
            Digit.rule {
                Char
                
                %?(Char~ >= "0" && Char~ <= "9")
                                
                Char~.match("0" => 0, "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9) --> Digit
            }
        }
    }
    
}
