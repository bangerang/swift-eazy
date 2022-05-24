import Foundation
import Combine

/// A type that can handle an action.
@MainActor
public protocol Actionable {
    associatedtype State: Equatable
    associatedtype Action: Equatable
    /// Called when the store dispatch an action.
    func onAction(_ action: Action, store: MutatingStore<State, Action>) async
}

/// A type that can handle a hook.
@MainActor
public protocol Hookable {
    associatedtype State: Equatable
    associatedtype Action: Equatable
    associatedtype Hook: CaseIterable
    /// Called on Store init when configuring hooks.
    func publisher(for hook: Hook, store: MutatingStore<State, Action>) -> AnyCancellable
}

public typealias Interactor = Actionable & Hookable

