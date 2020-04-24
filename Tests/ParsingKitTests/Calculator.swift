import ParsingKit
import FirstOrderDeepEmbedding


class Calculator : Grammar {
    
    typealias N = Nonterminal<UNIT, INT>
    
    @Sym var Expr : N
    @Sym var Sum : N
    @Sym var Product : N
    @Sym var Num : N
    @Sym var Digit : N
    @Sym var Char : Terminal<UNIT, CHAR>
        
    let ambiguous : Bool
    
    init(ambiguous : Bool) {
        self.ambiguous = ambiguous
    }
    
    public func lit(_ chars : String) -> RuleBody {
        var bodies : [RuleBody] = []
        for c in chars {
            let index = TUID()
            let body = collectRuleBody {
                Char[index]
                %?(Char[index].out == CHAR(c))
            }
            bodies.append(body)
        }
        return collectRuleBody(bodies)
    }

    override func build() {
        add {
            Expr.rule {
                Sum
                                
                Sum.out --> Expr
            }

            Sum.rule {
                Sum[1]
                lit("+")
                Product
                
                Sum[1].out + Product.out --> Sum
            }

            Sum.rule {
                Product
                                
                Product.out --> Sum
            }

            Product.rule {
                Product[1]
                lit("*")
                Num
                
                Product[1].out * Num.out --> Product
            }
            
            Product.rule {
                Num

                Num.out --> Product
            }
            
            Num.rule {
                Digit
                
                Digit.out --> Num
            }
            
            
            if !ambiguous {
                Num.rule {
                    Num[1]
                    Digit
                                        
                    Num[1].out * 10 + Digit.out --> Num
                }
            }
            
            if ambiguous {
                Num.rule {
                    Num[1]
                    Num[2]
                                        
                    Num[1].out * 10 + Num[2].out --> Num
                }
            }
            
            Digit.rule {
                Char
                
                %?(Char.out >= "0" && Char.out <= "9")
                                
                Char.out.match("0" => 0, "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9) --> Digit
            }
        }
    }
    
}
