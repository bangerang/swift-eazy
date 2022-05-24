import Foundation

public extension Equatable {
    mutating func with(setter: (inout Self) -> Void) -> Self {
        setter(&self)
        return self
    }
}
