import Foundation

/// An action that can be cancelled.
public protocol CancellableAction {
    var cancelIdentifier: String? { get }
}

public enum EmptyAction: Equatable {}
