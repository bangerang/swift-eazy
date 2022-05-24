import Foundation
import Combine
import CustomDump

/// A publisher that wraps another publisher.
public struct HookPublisher<T, E: Error>: Publisher {

    public typealias Failure = E
    public typealias Output = T
    
    private let publisher: AnyPublisher<T, E>
    private let hook: String
    
    public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
        self.publisher = publisher.eraseToAnyPublisher()
        hook = HookRepository.hooks.removeFirst()
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, E == S.Failure, T == S.Input {
        self.publisher
            .handleEvents(receiveOutput: { value in
                HookRepository.hookReceivedOutput.send((hook, value))
            })
            .receive(subscriber: subscriber)
    }
}

class HookRepository {
    static let hookReceivedOutput = PassthroughSubject<(hook: String, value: Any), Never>()
    static var hooks: [String] = []
}
