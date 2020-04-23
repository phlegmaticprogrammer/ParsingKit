public enum Position : Hashable, HasPosition {
    
    case unknown
    
    case position(file : String, line : Int)
    
    var position : Position {
        return self
    }

}

protocol HasPosition {
    
    var position : Position { get }
    
}

extension HasPosition {
    
    public func otherwise(_ other : HasPosition) -> HasPosition {
        switch position {
        case .unknown: return other
        case .position: return self
        }
    }
    
}
