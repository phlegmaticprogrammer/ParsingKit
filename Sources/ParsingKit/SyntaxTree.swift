//
//  SyntaxTree.swift
//
//  Created by Steven Obua on 24/07/2021.
//

import Foundation

public final class SyntaxTree : Hashable {
    
    public let symbol : String
    
    public let from: Int
    
    public let to: Int
    
    public let alternatives: [SyntaxTree]
    
    public let paramIn : AnyHashable
    
    public let paramOut : AnyHashable
    
    public let children : [SyntaxTree]
    
    public init(symbol : String, from : Int, to : Int, children : [SyntaxTree], paramIn : AnyHashable, paramOut : AnyHashable, alternatives : [SyntaxTree]) {
        self.symbol = symbol
        self.from = from
        self.to = to
        self.children = children
        self.paramIn = paramIn
        self.paramOut = paramOut
        self.alternatives = alternatives
    }
    
    private func explodeFirstCase() -> Set<SyntaxTree> {
        var explodedChildren : [[SyntaxTree]] = [[]]
        
        for child in children {
            let cases = child.explode()
            var newExplodedChildren : [[SyntaxTree]] = []
            for children in explodedChildren {
                for c in cases {
                    newExplodedChildren.append(children + [c])
                }
            }
            explodedChildren = newExplodedChildren
        }
        
        return Set(explodedChildren.map { children in
            SyntaxTree(symbol: symbol, from: from, to: to, children: children, paramIn: paramIn, paramOut: paramOut, alternatives: [])
        })
    }
    
    public func explode() -> Set<SyntaxTree> {
        var trees : Set<SyntaxTree> = []
        for i in 0 ..< countCases {
            trees.formUnion(self.case(i).explodeFirstCase())
        }
        return trees
    }
    
    public static func == (lhs: SyntaxTree, rhs: SyntaxTree) -> Bool {
        guard lhs.symbol == rhs.symbol && lhs.from == rhs.from && lhs.to == rhs.to else { return false }
        guard lhs.paramIn == rhs.paramIn && lhs.paramOut == rhs.paramOut else { return false }
        guard lhs.children == rhs.children && lhs.alternatives == rhs.alternatives else { return false }
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(symbol)
        hasher.combine(from)
        hasher.combine(to)
        hasher.combine(paramIn)
        hasher.combine(paramOut)
    }

    public var countCases : Int {
        return alternatives.count + 1
    }
    
    public var isAmbiguous : Bool {
        guard alternatives.count == 0 else { return true }
        for child in children {
            guard !child.isAmbiguous else { return true }
        }
        return false
    }
        
    public func `case`(_ index : Int) -> SyntaxTree {
        if index == 0 {
            return self
        } else {
            return alternatives[index - 1]
        }
    }

    public func debug(output : CodeOutput = DefaultCodeOutput()) {
        output.write("\(symbol)")
        func debugChildren(_ children : [SyntaxTree]) {
            output.indent()
            if children.count > 1 {
                for i in 0 ..< children.count {
                    children[i].debug(output: output)
                }
            } else if children.count == 1 {
                children[0].debug(output: output)
            }
            output.unindent()
        }
        if countCases > 1 {
            output.writeln(", \(countCases) cases")
            for caseIndex in 0 ..< countCases {
                let c = self.case(caseIndex)
                output.writeln("case \(caseIndex + 1):")
                debugChildren(c.children)
            }
        } else {
            output.writeln("")
            debugChildren(children)
        }
    }

    public static func from(parseTree : ParseTree, grammar : Grammar) -> SyntaxTree {
        let converter = Converter(grammar: grammar)
        return converter.convert(parseTree: parseTree)
    }

    private class Converter {
        
        let grammar : Grammar
        
        public init(grammar : Grammar) {
            self.grammar = grammar
        }
        
        public func convert(parseTree : ParseTree) -> SyntaxTree {
            let symbol = parseTree.key.symbol
            guard let props = grammar.propertiesOf(symbol) else {
                fatalError("symbol '\(symbol)' does not occur in grammar")
            }
            switch props.structure {
            case .Deep: return convert(deep: parseTree)
            case .Flat: return convert(flat: parseTree)
            }
        }

        func convert(parseTree: ParseTree, csts: inout [[SyntaxTree]]) {
            let symbol = parseTree.key.symbol
            guard let props = grammar.propertiesOf(symbol) else {
                fatalError("symbol '\(symbol)' does not occur in grammar")
            }
            switch props.visibility {
            case .Visible:
                switch props.structure {
                case .Deep:
                    append(cst: convert(deep: parseTree), csts: &csts)
                case .Flat:
                    append(cst: convert(flat: parseTree), csts: &csts)
                }
            case .Auxiliary:
                switch props.structure {
                case .Deep:
                    convert(auxiliary: parseTree, csts: &csts)
                case .Flat:
                    break
                }
            }
        }
        
        func convert(flat parseTree : ParseTree) -> SyntaxTree {
            let key = parseTree.key
            let from = key.startPosition
            let to = key.endPosition
            let paramIn = key.inputParam
            let paramOut = key.outputParam
            let symbol = key.symbol.name
            return SyntaxTree(symbol: symbol, from: from, to: to, children: [], paramIn: paramIn, paramOut: paramOut, alternatives: [])
        }
        
        func convert(deep parseTree : ParseTree) -> SyntaxTree {
            switch parseTree {
            case let .forest(key: _, trees: trees) where !trees.isEmpty:
                return convert(forest: trees)
            case let .forest(key: key, trees: _):
                let from = key.startPosition
                let to = key.endPosition
                let paramIn = key.inputParam
                let paramOut = key.outputParam
                return SyntaxTree(symbol: key.symbol.name, from: from, to: to, children: [], paramIn: paramIn, paramOut: paramOut, alternatives: [])
            case let .rule(id: _, key: key, rhs: rhs):
                let parallelCsts = convert(parseTrees: rhs)
                let from = key.startPosition
                let to = key.endPosition
                let paramIn = key.inputParam
                let paramOut = key.outputParam
                var allCases : [SyntaxTree] = []
                let symbol = key.symbol.name
                for csts in parallelCsts {
                    let cst = SyntaxTree(symbol: symbol, from: from, to: to, children: csts, paramIn: paramIn, paramOut: paramOut, alternatives: [])
                    allCases.append(cst)
                }
                return make(allCases: allCases)!
            }
        }

        func convert(forest : Set<ParseTree>) -> SyntaxTree {
            guard forest.count > 1 else { fatalError("trying to convert forest with \(forest.count) children") }
            var alternatives : [SyntaxTree] = []
            for tree in forest {
                let t = convert(parseTree: tree)
                if t.countCases > 1 {
                    let first = SyntaxTree(symbol: t.symbol, from: t.from, to: t.to, children: t.children, paramIn: t.paramIn, paramOut: t.paramOut, alternatives: [])
                    alternatives.append(first)
                    alternatives.append(contentsOf: t.alternatives)
                } else {
                    alternatives.append(t)
                }
            }
            return make(allCases: alternatives)!
        }
        
        func make(allCases: [SyntaxTree]) -> SyntaxTree? {
            switch allCases.count {
            case 0: return nil
            case 1: return allCases[0]
            default: break
            }
            for c in allCases {
                if c.alternatives.count > 0 {
                    print("more alternatives: \(c.alternatives.count)")
                    for i in 0 ..< c.countCases {
                        print("case \(i): \(c.case(i))")
                    }
                    return nil
                }
            }
            let first = allCases.first!
            let alternatives = Array(allCases.dropFirst())
            return SyntaxTree(symbol: first.symbol, from: first.from, to: first.to, children: first.children, paramIn: first.paramIn, paramOut: first.paramOut, alternatives: alternatives)
        }

        func convert<S:Sequence>(forest : S, csts : inout [[SyntaxTree]]) where S.Element == ParseTree {
            var parallel : [[SyntaxTree]] = []
            for tree in forest {
                parallel.append(contentsOf: convert(parseTrees: [tree]))
            }
            var newCsts : [[SyntaxTree]] = []
            for q in csts {
                for p in parallel {
                    newCsts.append(q + p)
                }
            }
            csts = newCsts
        }
        
        func convert(parseTrees : [ParseTree], csts : inout [[SyntaxTree]]) {
            for parseTree in parseTrees {
                convert(parseTree: parseTree, csts: &csts)
            }
        }
        
        func convert(parseTrees : [ParseTree]) -> [[SyntaxTree]] {
            var csts : [[SyntaxTree]] = [[]]
            convert(parseTrees: parseTrees, csts: &csts)
            return csts
        }

        func append(cst : SyntaxTree, csts : inout [[SyntaxTree]]) {
            for i in 0 ..< csts.count {
                csts[i].append(cst)
            }
        }
        
        func convert(auxiliary parseTree: ParseTree, csts : inout [[SyntaxTree]]) {
            switch parseTree {
            case let .forest(key: _, trees: trees) where !trees.isEmpty:
                convert(forest: trees, csts: &csts)
            case .forest:
                // it's a terminal without any children
                break
            case let .rule(id: _, key: _, rhs: rhs): convert(parseTrees: rhs, csts: &csts)
            }
        }

    }

}


