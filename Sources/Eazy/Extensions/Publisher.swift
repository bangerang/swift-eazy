import Foundation
import Combine
import SwiftUI

public extension Publisher where Failure == Never {
    func assign<Root, Action>(to keyPath: WritableKeyPath<Root, Output>, using store: MutatingStore<Root, Action>, animation: AnimationOption = .none, forceUpdate: Bool = false) -> AnyCancellable {
        return sink { [weak store] value in
            Task { @MainActor [weak store] in
                switch animation {
                case .none:
                    store?.set(keyPath, value, forceUpdate: forceUpdate)
                case .`default`:
                    withAnimation {
                        store?.set(keyPath, value, forceUpdate: forceUpdate)
                    }
                case .custom(let animation):
                    withAnimation(animation) {
                        store?.set(keyPath, value, forceUpdate: forceUpdate)
                    }
                }
                
            }
        }
    }
    
    func assign<Root, Action>(toAction action: Action, using store: MutatingStore<Root, Action>) -> AnyCancellable {
        return sink { [weak store] value in
            Task { @MainActor [weak store] in
                store?.dispatch(action)
            }
        }
    }
    
    func assign<Root, Action>(toAction action: @escaping (Output) -> Action, using store: MutatingStore<Root, Action>) -> AnyCancellable {
        return sink { [weak store] value in
            Task { @MainActor [weak store] in
                store?.dispatch(action(value))
            }
        }
    }
    
    func weakAssign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on root: Root) -> AnyCancellable {
       sink { [weak root] in
            root?[keyPath: keyPath] = $0
        }
    }
}

extension Publisher {
    func stream(timeout: Double = 1, scheduler: DispatchQueue = .main) async throws -> AsyncThrowingStream<Output, Error> {
        var cancellable: AnyCancellable?
        return AsyncThrowingStream<Output, Error> { continuation in
            cancellable = self
                .timeout(.seconds(timeout), scheduler: scheduler)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    case .finished:
                        continuation.finish()
                    }
                    cancellable?.cancel()
                }, receiveValue: { value in
                    continuation.yield(value)
                }
            )
        }
    }
}
extension Publisher where Failure == Never {
    func stream(timeout: Double = 1, scheduler: DispatchQueue = .main) async -> AsyncStream<Output> {
        var cancellable: AnyCancellable?
        return AsyncStream<Output> { continuation in
            cancellable = self
                .timeout(.seconds(timeout), scheduler: scheduler)
                .sink(receiveCompletion: { completion in
                        continuation.finish()
                        cancellable?.cancel()
                    }, receiveValue: { value in
                        continuation.yield(value)
                    }
                )
        }
    }
}

public extension Publisher where Failure == Never {
    func first(timeout: Double = 1, scheduler: DispatchQueue = .main) async -> Output? {
        for await value in await self.prefix(1).stream(timeout: timeout, scheduler: scheduler) {
            return value
        }
        return nil
    }
}

public extension Publisher {
    func log(_ message: @escaping (Self.Output) -> String) -> AnyPublisher<Self.Output, Self.Failure> {
        handleEvents(receiveOutput: { output in
            Swift.print(message(output))
        })
        .eraseToAnyPublisher()
    }
}
