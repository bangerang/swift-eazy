import Combine
import Foundation
import SwiftUI
import CustomDump

@MainActor
protocol TaskOwner: AnyObject {
    func getTask(from identifier: String) -> Task<Void, Never>?
    func saveTask(_ task: Task<Void, Never>, for identifier: String?)
}

/// A ``StateStore`` is a StateObject which we can use in SwiftUI views to listen to state changes, retrieve bindings and dispatch actions.
/// Since this is a StateObject we can safely use dependency injection or simply create a store directly in the view.
///
/// ```swift
/// struct MyView: View {
///     @StateStore var store: Store<ViewState, Action>
///
///     var body: some View {
///         TextField($store.title)
///         Button("Button") {
///             store.dispatch(.someAction)
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct StateStore<State: Equatable, Action: Equatable>: DynamicProperty {
    @StateObject private var store: Store<State, Action>
    
    public var wrappedValue: Store<State, Action> {
        return store
    }
    
    public var projectedValue: Store<State, Action>.Binder {
        return store.binder
    }
    
    public init(wrappedValue thunk: @autoclosure @escaping () -> Store<State, Action>) {
        _store = .init(wrappedValue: thunk())
    }
}

/// A ``StatePublisher`` is a publisher that can be used to listen for state changes.
@MainActor @dynamicMemberLookup
public class StatePublisher<State: Equatable, Action: Equatable>: Publisher {
    
    struct Provider {
        let previousState: () -> State?
        let objectChanged: () -> AnyPublisher<State, Never>
    }
    
    public typealias Output = State
    public typealias Failure = Never
    
    var explicitKeyPathChange: PartialKeyPath<State>?
    
    private let provider: Provider
    
    init(provider: Provider) {
        self.provider = provider
    }
    
    public func publisher<T: Equatable>(for keyPath: KeyPath<State, T>) -> AnyPublisher<T, Never> {
        return provider.objectChanged()
            .map { $0[keyPath: keyPath] }
            .compactMap { [weak self] value in
                return self?.decideNextValue(dynamicMember: keyPath, value: value)
            }
            .eraseToAnyPublisher()
    }
    
    public subscript<T: Equatable>(dynamicMember keyPath: KeyPath<State, T>) -> AnyPublisher<T, Never> {
        return provider.objectChanged()
            .map { $0[keyPath: keyPath] }
            .compactMap { [weak self] value in
                return self?.decideNextValue(dynamicMember: keyPath, value: value)
            }
            .eraseToAnyPublisher()
    }
    
    public nonisolated func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, State == S.Input {
        provider
            .objectChanged()
            .removeDuplicates()
            .receive(subscriber: subscriber)
    }
    
    private func decideNextValue<T: Equatable>(dynamicMember keyPath: KeyPath<State, T>, value: T) -> T? {
        if let previous = provider.previousState() {
            if previous[keyPath: keyPath] != value {
                return value
            } else if explicitKeyPathChange == (keyPath as PartialKeyPath<State>) {
                return value
            } else {
                return nil
            }
        } else {
            return value
        }
    }
}

/// A representation of ``Store`` that can mutate state.
@MainActor @dynamicMemberLookup
public class MutatingStore<State: Equatable, Action: Equatable> {
    
    weak var taskOwner: TaskOwner?
    
    /// A snapshot of the current state
    public var state: State {
        modelService.snapshot
    }
    
    /// A publisher for observaring state changes.
    public var publisher: StatePublisher<State, Action> {
        return publisherService
    }
    
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<ModelService<State>, T>) -> T {
        get {
            return modelService[keyPath: keyPath]
        } set {
            modelService[keyPath: keyPath] = newValue
        }
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<ModelService<State>, T>) -> T {
        return modelService[keyPath: keyPath]
    }
    
    fileprivate let didDispatchAction: PassthroughSubject<Action, Never> = .init()
    
    fileprivate var onAction: @MainActor (Action, MutatingStore<State, Action>) async -> Void
    
    private var modelService: ModelService<State>
    
    private var previous: State?
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var publisherService: StatePublisher<State, Action> = .init(provider: .init(
        previousState: { [weak self] in
            return self?.previous
        },
        objectChanged: { [weak self] in
            guard let self = self else {
                fatalError()
            }
            return self.modelService.publisher
    }))
    
    init(modelService: ModelService<State>,
         onAction: @escaping @MainActor (Action, MutatingStore<State, Action>) async -> Void) {
        self.modelService = modelService
        self.onAction = onAction
        modelService.publisherPrevious.sink { [weak self] value in
            self?.previous = value
        }
        .store(in: &cancellables)
    }
    
    /// A explicit setter of state by keypath.
    ///
    /// - By default state changes are only broadcasted when some value has changed. This function offers a way to broadcast a change even if nothing has changed.
    /// - Parameters:
    ///   - keyPath: A writable keypath to a state property
    ///   - forceUpdate: Force a broadcast update
    public func set<T>(_ keyPath: WritableKeyPath<State, T>, _ value: T, forceUpdate: Bool = false) {
        assert(Thread.isMainThread, "Called set from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        if forceUpdate {
            publisher.explicitKeyPathChange = keyPath
        }
        
        var copy = modelService.snapshot
        copy[keyPath: keyPath] = value
        modelService.set(copy)
        
        publisher.explicitKeyPathChange = nil
    }
    
    /// Dispatch an action without awaiting the result.
    ///
    /// Must be called on main thread.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch to the store
    public func dispatch(_ action: Action) {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        _dispatch(action)
    }
    
    /// Dispatch an action by awaiting the result.
    ///
    /// Must be called on main thread.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch to the store
    public func dispatch(_ action: Action) async {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        await _dispatch(action).value
    }
    
    /// Cancels an action if that action conforms to ``CancellableAction`` and returns a valid identifier.
    /// - Parameters:
    ///   - action: The action to cancel
    public func cancel(_ action: Action) where Action: CancellableAction {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        if let identifier = action.cancelIdentifier {
            if let task = taskOwner?.getTask(from: identifier) {
                task.cancel()
            }
        }
    }
    
    @discardableResult
    private func _dispatch(_ action: Action) -> Task<Void, Never> {
        let identifier = (action as? CancellableAction)?.cancelIdentifier
        if let identifier = identifier {
            if let task = taskOwner?.getTask(from: identifier) {
                task.cancel()
            }
        }
        
        let task = Task { @MainActor in
            await onAction(action, self)
        }
        
        didDispatchAction.send(action)
        
        taskOwner?.saveTask(task, for: identifier)
        
        return task
    }
}

public enum AnimationOption {
    case none
    case `default`
    case custom(Animation)
}

/// A ``Store`` is the representation and encapsulation of our application logic.
///
/// ```swift
/// struct MyView: View {
///     @StateStore var store: Store<ViewState, Action>
///
///     var body: some View {
///         TextField($store.title)
///         Button("Button") {
///             store.dispatch(.someAction)
///         }
///     }
/// }
/// ```
/// - Note: Owner of any ongoing tasks and cancellables. Both will be cancelled on deallocation of this object.
@MainActor @dynamicMemberLookup
public class Store<State: Equatable, Action: Equatable>: ObservableObject, TaskOwner {
    
    /// A Binder offers a way to retrieve a binding value for a state property or an action.
    @MainActor @dynamicMemberLookup
    public struct Binder {
        let store: MutatingStore<State, Action>
        
        /// Retrieve a binding value to a state property by using a writable keypath
        ///
        /// - Parameters:
        ///     - keyPath: A writable keypath to a state property
        ///
        /// - Returns: A binding to a state property
        func binding<T: Equatable>(for keyPath: WritableKeyPath<State, T>) -> Binding<T> {
            return Binding(
                get: {
                    store.state[keyPath: keyPath]
                },
                set: { value in
                    logIfEnabled(keyPath, value)
                    store.set(keyPath, value)
                }
            )
        }
        
        /// Create a binding that has read only access to a state property and perform an action on set.
        /// - Parameters:
        ///     - get: A closure to a state property
        ///     - action: A closure to an action
        /// - Returns: A binding with read only access that performs an action on set
        public func binding<T>(get: @escaping (State) -> T,
                               action toAction: @escaping (T) -> Action) -> Binding<T> {
            return Binding(
                get: {
                    get(store.state)
                },
                set: { value in
                    store.dispatch(toAction(value))
                }
            )
        }
        
        public subscript<T: Equatable>(dynamicMember keyPath: WritableKeyPath<State, T>) -> Binding<T> {
            return Binding(
                get: {
                    store.state[keyPath: keyPath]
                },
                set: { value in
                    logIfEnabled(keyPath, value)
                    store.set(keyPath, value)
                }
            )
        }
        
        private func logIfEnabled<T: Equatable>(_ keyPath: WritableKeyPath<State, T>, _ value: T) {
            guard DebugStore.logEnabledType.isEnabled(type: State.self) else {
                return
            }
            let oldState = store.state
            var newState = store.state
            newState[keyPath: keyPath] = value
            let oldProps = oldState.allProperties()
            let newProps = newState.allProperties()
            for (key, v) in newProps {
                if v as? T == value && oldProps[key] as? T != value {
                    let type = String(describing: Action.self).replacingOccurrences(of: ".Type", with: "")
                    let action = #"\#(type).binding.\#(key)("\#(value)")"#
                    LoggerProxy.log(from: State.self, logAction: Logger.logBindingString(action, print: DebugStore.print))
                    break
                }
            }
        }
    }
    
    public let binder: Binder
    
    public var publisher: StatePublisher<State, Action> {
        return statePublisher
    }
    
    public var state: State {
        return modelService.snapshot
    }
    
    @ObservedObject fileprivate var modelService: ModelService<State>
    
    private var unknownTasks: [Task<Void, Never>] = []
    
    private var onAction: @MainActor (Action, MutatingStore<State, Action>) async -> Void = {_, _ in}
    
    private var previous: State?
    
    fileprivate var cancellables: Set<AnyCancellable> = []
    
    fileprivate var cancellableTasks: [String: Task<Void, Never>] = [:]
    
    fileprivate var mutatingStore: MutatingStore<State, Action>
    
    private lazy var statePublisher: StatePublisher<State, Action> = .init(provider: .init(
        previousState: { [weak self] in
            return self?.previous
        },
        objectChanged: { [weak self] in
            guard let self = self else {
                fatalError()
            }
            return self.modelService.publisher
                .eraseToAnyPublisher()
        }))
    
    public convenience init<I: Interactor>(state: State, interactor: I) where I.State == State, I.Action == Action {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        self.init(state: state)
        setupActions(with: interactor)
        setupHooks(with: interactor)
    }
    
    public convenience init<A: Actionable>(state: State, actionable: A) where A.State == State, A.Action == Action {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        self.init(state: state)
        setupActions(with: actionable)
    }
    
    public convenience init<H: Hookable>(state: State, hookable: H) where H.State == State, H.Action == Action {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        self.init(state: state)
        setupHooks(with: hookable)
    }
    
    public required init(state: State) {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        LoggerProxy.log(from: State.self, logAction: Logger.logInitialState(state, print: DebugStore.print))
        
        let modelService = ModelService(state)
        self.modelService = modelService
        
        self.mutatingStore = MutatingStore(modelService: modelService,
                             onAction: onAction)
        
        self.binder = Binder(store: mutatingStore)
        
        self.modelService.publisher.sink { [weak self] value in
            LoggerProxy.log(from: State.self, logAction: Logger.logStateChange(old: self?.previous, new: value, print: DebugStore.print))
        }.store(in: &cancellables)
        
        self.modelService.publisherPrevious.sink { [weak self] value in
            self?.previous = value
        }.store(in: &cancellables)
        
        self.modelService.objectWillChange.sink(receiveValue: { [weak self] in
            self?.objectWillChange.send()
        }).store(in: &cancellables)
    }
    
    deinit {
        cancellableTasks.forEach {
            $0.value.cancel()
        }
        unknownTasks.forEach {
            $0.cancel()
        }
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        return state[keyPath: keyPath]
    }
    
    /// Dispatch an action by awaiting the result.
    ///
    /// Must be called on main thread.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch to the store
    public func dispatch(_ action: Action) async {
        await mutatingStore.dispatch(action)
    }
    
    /// Dispatch an action without awaiting the result.
    ///
    /// Must be called on main thread.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch to the store
    public func dispatch(_ action: Action) {
        mutatingStore.dispatch(action)
    }
    
    /// Cancels an action if that action conforms to ``CancellableAction`` and returns a valid identifier.
    /// - Parameters:
    ///   - action: The action to cancel
    public func cancel(_ action: Action) where Action: CancellableAction {
        mutatingStore.cancel(action)
    }
    
    /// Deactivate any ongoing hooks.
    public func deactiveHooks() {
        assert(Thread.isMainThread, "Called from a background thread, this is illegal and will lead to unexpected results and behaviour.")
        cancellables.removeAll()
    }
    
    fileprivate func setupActions<A: Actionable>(with actionable: A) where A.State == State, A.Action == Action {
        self.mutatingStore.onAction = { action, store in
            LoggerProxy.log(from: State.self, logAction: Logger.logAction(action, print: DebugStore.print))
            store.didDispatchAction.send(action)
            await actionable.onAction(action, store: store)
        }
        self.mutatingStore.taskOwner = self
    }
    
    fileprivate func setupHooks<H: Hookable>(with hookable: H) where H.State == State, H.Action == Action {
        var hooks: Set<AnyCancellable> = []
        var hookIdentifiers: Set<String> = []
        H.Hook.allCases.forEach { hook in
            let identifier = makeHookIdentifier(hook)
            hookIdentifiers.insert(identifier)
            HookRepository.hooks.append(identifier)
            hooks.insert(hookable.publisher(for: hook, store: mutatingStore))
        }
        cancellables.formUnion(hooks)
        
        HookRepository.hookReceivedOutput.sink { data in
            if hookIdentifiers.contains(data.hook) {
                LoggerProxy.log(from: State.self, logAction: Logger.logHook(data.hook, data.value, print: DebugStore.print))
            }
        }.store(in: &cancellables)
    }
    
    func getTask(from identifier: String) -> Task<Void, Never>? {
        return cancellableTasks[identifier]
    }
    
    func saveTask(_ task: Task<Void, Never>, for identifier: String?) {
        if let identifier = identifier {
            cancellableTasks[identifier] = task
        } else {
            unknownTasks.append(task)
        }
    }
}

fileprivate extension Store {
    func makeHookIdentifier<Hook>(_ hook: Hook) -> String {
        return "\(String(describing: type(of: hook))).\(hook)"
    }
}

/// A ``ModelService`` is an ObservableObject that manages the current state.
@MainActor @dynamicMemberLookup
public class ModelService<State: Equatable>: ObservableObject {
    
    public var snapshot: State {
        return backing
    }
    
    public var publisherPrevious: AnyPublisher<State?, Never> {
        return $previous
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    public var publisher: AnyPublisher<State, Never> {
        return $backing
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    @Published private var backing: State
    @Published private var previous: State?
    
    init(_ backing: State) {
        self.backing = backing
    }
    
    func set(_ new: State) {
        previous = backing
        objectWillChange.send()
        backing = new
    }
    
    public subscript<T: Equatable>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            backing[keyPath: keyPath]
        }
        set {
            previous = backing
            objectWillChange.send()
            backing[keyPath: keyPath] = newValue
        }
    }
    
    public subscript<T: Equatable>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        return backing[keyPath: keyPath]
    }
}

/// A ``TestStore`` is a test utility that can be used for writing test code.
public class TestStore<State: Equatable, Action: Equatable>: Store<State, Action> {

    public private(set) var stateUpdates: [State] = []
    public private(set) var triggeredActions: [Action] = []
    public fileprivate(set) var didTriggerHook = false

    public convenience init<I>(state: State, interactor: I) where State == I.State, Action == I.Action, I : Interactor {
        self.init(state: state)
        setupActions(with: interactor)
        setupHooks(with: interactor)
        
        mutatingStore.publisher.sink { [weak self] value in
            self?.stateUpdates.append(value)
        }.store(in: &cancellables)
        
        mutatingStore.didDispatchAction.sink { [weak self] action in
            self?.triggeredActions.append(action)
        }.store(in: &cancellables)
    }
    
    public static func testHook<I: Interactor>(_ hook: I.Hook, trigger: @escaping @autoclosure () -> Void, state: State, interactor: I, timeout: Double = 1) async -> TestStore<State, Action> where State == I.State, Action == I.Action {
        let store = TestStore(state: state, interactor: interactor)
        let identifier = store.makeHookIdentifier(hook)
        
        await Task { @MainActor in
            let stream = await HookRepository.hookReceivedOutput.prefix(1).stream()
            trigger()
            for await data in stream {
                if data.hook == identifier {
                    store.didTriggerHook = true
                }
            }
            let oneSecond = Double(1_000_000_000)
            let delay = UInt64(oneSecond * timeout)
            try? await Task.sleep(nanoseconds: delay)
        }.value
        
        return store
    }
    
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<MutatingStore<State, Action>, T>) -> T {
        get {
            return mutatingStore[keyPath: keyPath]
        } set {
            mutatingStore[keyPath: keyPath] = newValue
        }
    }
    
    public override subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        return state[keyPath: keyPath]
    }
    
    public func didTrigger(_ action: Action) async -> Bool {
        return await mutatingStore.didDispatchAction.first() == action
    }

    public func didTrigger(_ action: Action) -> Bool {
        return triggeredActions.contains(action)
    }
}

private extension Equatable {
    func allProperties() -> [String: Any] {
        var result: [String: Any] = [:]
        
        let mirror = Mirror(reflecting: self)
        
        for (property, value) in mirror.children {
            guard let property = property else {
                continue
            }
            result[property] = value
        }
        
        return result
    }
}
