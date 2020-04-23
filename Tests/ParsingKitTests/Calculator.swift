import ParsingKit

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
    
    override func build() {
        add {
            Expr.rule {
                Sum
                                
                Sum.out --> Expr
            }

            Sum.rule {
                Sum[1]
                Char
                Product
                
                %?(Char.out == "+")
                Sum[1].out + Product.out --> Sum
            }

            Sum.rule {
                Product
                                
                Product.out --> Sum
            }

            Product.rule {
                Product[1]
                Char
                Num
                
                %?(Char.out == "*")
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


/*func parseExample(_ g : Grammar<CODEPOINT>, input : String, results : Set<Int>) {
    let result = g.parse(input: Codepoints(input))
    XCTAssertTrue(!result.error)
    XCTAssertEqual(result.length, input.count)
    XCTAssertEqual(result.results.count, results.count)
    for r in result.results {
        XCTAssertTrue(r.0.globals.isEmpty)
        let trees = Set(ParseTree.explode(r.1).map { tree in tree.result as! Int })
        XCTAssertEqual(trees.count, 1)
        XCTAssertEqual(trees.first!, r.0.out as! Int)
        XCTAssert(results.contains(trees.first!))
    }
}*/

