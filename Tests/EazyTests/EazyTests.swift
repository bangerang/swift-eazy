import XCTest
import Combine
@testable import Eazy

final class EazyTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    
    @MainActor
    func testStatePublisherShouldBeCalledOnStateChange() async throws {
        let store = Store(state: TestState(foo: "foo", bar: 123),
                          actionable: TestActionable(
                            handleAction: { action, store in
                                if case .someAction = action {
                                    store.foo = "bar"
                                } else {
                                    XCTFail()
                                }
                            }
                          )
        )
        
        await store.dispatch(.someAction)
        XCTAssertEqual(store.foo, "bar")
    }
    
    @MainActor
    func testPublisherForAllShouldBeCalledOnStateChange() async throws {
        let expected = TestState(foo: "bar", bar: 123)
        
        let store = Store(state: TestState(foo: "foo", bar: 123),
                          actionable: TestActionable(
                            handleAction: { action, store in
                                if case .someAction = action {
                                    store.foo = "bar"
                                } else {
                                    XCTFail()
                                }
                            }
                          )
        )
        
        await store.dispatch(.someAction)
        XCTAssertEqual(store.state, expected)
    }
    
    @MainActor
    func testBinding() async throws {
        let store = Store<TestState, EmptyAction>(state: TestState(foo: "foo", bar: 123))
        
        store.binder.foo.wrappedValue = "bar"
        XCTAssertEqual(store.foo, "bar")
    }
    
    @MainActor
    func testHookGetsCalled() async throws {
        var hookCalled = false
        let store = Store(state: TestState(foo: "foo", bar: 123),
                          interactor: TestInteractor(
                            handleAction: { action, store in
                                store.foo = "called"
                            },
                            publisherForHook: { hook, store in
                                switch hook {
                                case .fooChanged:
                                    return HookPublisher(store.publisher.foo)
                                        .sink { value in
                                            XCTAssertEqual(value, "called")
                                            hookCalled = true
                                        }
                                case .notificationChanged:
                                    return AnyCancellable {}
                                }
                            }
                          )
        )
        await store.dispatch(.someAction)
        XCTAssertTrue(hookCalled)
    }
    
    @MainActor
    func testAsyncStateChange() async {
        let dummy: () async -> Void = {
            try? await Task.sleep(nanoseconds: 0_100_000_000)
        }
        let store = Store(state: TestState(foo: "foo", bar: 123), actionable: TestActionable(
            handleAction: { action, store in
                await dummy()
                store.foo = "called"
            })
        )
        await store.dispatch(.someAction)
        XCTAssertEqual(store.foo, "called")
    }
    
    @MainActor
    func testDispatchActionFromHook() async throws {
        var didSendAction = false
        let store = Store(state: TestState(foo: "foo", bar: 123),
                          interactor: TestInteractor(
                            handleAction: { action, store in
                                switch action {
                                case .someAction:
                                    didSendAction = true
                                case .asyncAction:
                                    store.foo = "test"
                                }
                            },
                            publisherForHook: { hook, store in
                                switch hook {
                                case .fooChanged:
                                    return HookPublisher(store.publisher.foo)
                                        .sink { _ in
                                            store.dispatch(.someAction)
                                        }
                                case .notificationChanged:
                                    return AnyCancellable {}
                                }
                            }
                          )
        )
        await store.dispatch(.asyncAction)
        XCTAssertTrue(didSendAction)
    }
    
    func testActionGetsCancelled() async throws {
        let dummy: () async throws -> Void = {
            try await Task.sleep(nanoseconds: 0_100_000_000)
        }
        var count = 0
        let store = await Store(state: TestState(foo: "foo", bar: 123),
                                actionable: TestActionable(
                                    handleAction: { action, store in
                                        if case .asyncAction = action {
                                            count += 1
                                            do {
                                                try await dummy()
                                            } catch {
                                                XCTAssertEqual(count, 1)
                                                XCTAssertTrue(Task.isCancelled)
                                            }
                                        } else {
                                            XCTFail()
                                        }
                                    }
                                ))
        await withTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask {
                await store.dispatch(.asyncAction)
            }
            taskGroup.addTask {
                await store.dispatch(.asyncAction)
            }
        }
    }
    
    @MainActor
    func testDeallocation() {
        var calledCancel = false
        _ = Store(state: TestState(foo: "foo", bar: 123),
                  interactor: TestInteractor(
                    handleAction: { action, store in
                        switch action {
                        case .someAction:
                            break
                        case .asyncAction:
                            store.foo = "test"
                        }
                    },
                    publisherForHook: { hook, store in
                        return AnyCancellable {
                            calledCancel = true
                        }
                    }
                  )
        )
        XCTAssertTrue(calledCancel)
    }
}

struct TestState: Equatable {
    var foo: String
    var bar: Int
}

enum TestAction: Equatable, CancellableAction {
    case someAction
    case asyncAction
    
    var cancelIdentifier: String? {
        switch self {
        case .someAction:
            return nil
        case .asyncAction:
            return "asyncAction"
        }
    }
}

enum TestHook: CaseIterable {
    case fooChanged
    case notificationChanged
}

struct TestActionable: Actionable {
    let handleAction: (TestAction, MutatingStore<TestState, TestAction>) async -> Void
    
    func onAction(_ action: TestAction, store: MutatingStore<TestState, TestAction>) async {
        await handleAction(action, store)
    }
}

struct TestInteractor: Interactor {
    
    let handleAction: (TestAction, MutatingStore<TestState, TestAction>) async -> Void
    let publisherForHook: (TestHook, MutatingStore<TestState, TestAction>) -> AnyCancellable
    
    func onAction(_ action: TestAction, store: MutatingStore<TestState, TestAction>) async {
        await handleAction(action, store)
    }
    
    func publisher(for hook: TestHook, store: MutatingStore<TestState, TestAction>) -> AnyCancellable {
        return publisherForHook(hook, store)
    }
}
