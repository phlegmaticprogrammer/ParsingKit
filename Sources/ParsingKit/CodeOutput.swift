//
//  CodeOutput.swift
//
//  Created by Steven Obua on 24/07/2021.
//

public protocol CodeOutput {
    
    func indent()
    func unindent()
    func resetIndendation(body : () -> ())
    
    func write(_ s : String)
    
    func newline()
    func flush()
    
}

public extension CodeOutput {
    
    func writeln( _ s : String) {
        write(s)
        newline()
    }
    
}

public class DefaultCodeOutput : CodeOutput {
    
    private var indentation : Int = 0
    
    private var buffer : String?
    private var printLine : (String) -> ()
    
    public init(printLine : @escaping (String) -> () = { print($0) }) {
        self.buffer = nil
        self.printLine = printLine
    }
    
    public func indent() {
        indentation += 4
    }
    
    public func unindent() {
        indentation -= 4
    }
    
    public func resetIndendation(body: () -> ()) {
        flush()
        let oldIndentation = indentation
        indentation = 0
        body()
        flush()
        indentation = oldIndentation
    }
    
    public func write(_ s : String) {
        if let b = buffer {
            buffer = b + s
        } else {
            buffer = "\(String(repeating: " ", count: indentation))\(s)"
        }
    }
    
    public func newline() {
        if let b = buffer {
            printLine(b)
            buffer = nil
        } else {
            printLine("")
        }
    }
    
    public func flush() {
        guard let b = buffer else { return }
        printLine(b)
        buffer = nil
    }
    
}
