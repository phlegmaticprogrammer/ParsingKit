# [ParsingKit](https://github.com/phlegmaticprogrammer/ParsingKit) ![](https://github.com/phlegmaticprogrammer/ParsingKit/workflows/macOS/badge.svg)  ![](https://github.com/phlegmaticprogrammer/ParsingKit/workflows/Linux/badge.svg) 

Copyright (c) 2020 Steven Obua

License: MIT License

---

*ParsingKit* is a Swift package for composable parsing. Its foundation is [*Local Lexing*](https://github.com/phlegmaticprogrammer/EarleyLocalLexing). 
It is experimental in the sense that its goal is to explore how practical Local Lexing is, and how much it can actually facilitate composable parsing.

Its [API](https://phlegmaticprogrammer.github.io/ParsingKit) is not documented yet, and it hasn't been extensively tested yet. A document describing the principles on which ParsingKit is based is in the making.
For now, to get a feel for the framework, you can examine the existing tests. Here is an example grammar taken from them:

```swift
import FirstOrderDeepEmbedding
import ParsingKit

class Calculator : Grammar {
        
    @Sym var Expr : Nonterminal<UNIT, INT>
    @Sym var Sum : Nonterminal<UNIT, INT>
    @Sym var Product : Nonterminal<UNIT, INT>
    @Sym var Num : Nonterminal<UNIT, INT>
    @Sym var Digit : Nonterminal<UNIT, INT>
    @Sym var Char : Terminal<UNIT, CHAR>
                
    override func build() {
        add {
            Expr.rule {
                Sum
                                
                Sum~ --> Expr
            }

            Sum.rule {
                Sum[1]
                Char
                Product
                
                %?(Char~ == "+")
                Sum[1]~ + Product~ --> Sum
            }

            Sum.rule {
                Product
                                
                Product~ --> Sum
            }

            Product.rule {
                Product[1]
                Char
                Num
                
                %?(Char~ == "*")
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
                        
            Num.rule {
                Num[1]
                Digit
                                    
                Num[1]~ * 10 + Digit~ --> Num
            }
            
            Digit.rule {
                Char
                
                %?(Char~ >= "0" && Char~ <= "9")
                                
                Char~.match("0" => 0, "1" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5, "6" => 6, "7" => 7, "8" => 8, "9" => 9) --> Digit
            }
        }
    }
    
}
```


