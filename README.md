# Eazy
Eazy is the missing piece in your SwiftUI and UIKit application. It aims at harmonizing how your views communicate with the model and vice versa in a clear and consistent way. Eazy can be used on any Apple platform.

Eazy is a unidirectional architecture that takes a slightly different approach when it comes to mutating state. Let’s go through the core components in Eazy by looking at an example.

This example will go through a chat feature. In this feature we can post and receive new messages. Let’s start by defining the view state.

## State

```swift
struct ChatState: Equatable {
    struct Message: Equatable, Identifiable {
        enum From: Equatable {
            case other
            case me
        }
        let id = UUID()
        let from: From
        let text: String
    }
    enum MessagesState: Equatable {
        case loading
        case success([Message])
        case failure(String)
    }
    
    var messagesState: MessagesState = .loading
    var newMessageString = ""
}
```

And to retrieve and send those messages we need to define some actions.
## Action
```swift
enum ChatAction: Equatable {
    case getMessages
    case sendMessage
}
```

We also need to communicate with the outside world since we can recieve incoming messages. For that we can use a hook which we will call `messageRecieved`. Hooks can be used to observe internal state as well. Let's add a hook named `newMessageChanged` for when `newMessageString` changes so we can make sure to save any drafts if the user exits the screen.
## Hooks
```swift
enum ChatHook: CaseIterable {
    case messageRecieved
    case newMessageChanged
}
```

## Dependencies

Handling dependencies is a easy as defining a struct, or use a protocol if you like.

```swift
struct ChatService {
    let getMessages: () async throws -> [ChatState.Message]
    let sendMessage: (ChatState.Message) async -> Void
    let receivedMessage: AnyPublisher<ChatState.Message, Never>
    let cacheDraft: (String) -> Void
}
```

## Interactor

The interactor is where we decide how our state should transition. The interactor is responsible for handling our actions, both synchronous and asynchronous. For asynchronous actions we can use async await.
```swift
import Eazy

struct ChatInteractor: Interactor {
    
    let service: ChatService
    
    func onAction(_ action: ChatAction, store: MutatingStore<ChatState, ChatAction>) async {
        switch action {
        case .getMessages:
            do {
                store.messagesState = .loading
                let messages = try await service.getMessages()
                store.messagesState = .success(messages)
            } catch {
                store.messagesState = .failure("Something went wrong")
            }
        case .sendMessage:
            guard !store.newMessageString.isEmpty else {
                return
            }
            let message = ChatState.Message(from: .me, text: store.newMessageString)
            await service.sendMessage(message)
            store.newMessageString = ""
        }
    }
}
```

The interactor is also where we configure our hooks by using Combine publishers. 

```swift
struct ChatInteractor: Interactor {
    // ...
    func publisher(for hook: ChatHook, store: MutatingStore<ChatState, ChatAction>) -> AnyCancellable {
        switch hook {
        case .messageRecieved:
            return HookPublisher(service.receivedMessage)
                .sink { message in
                    if case .success(let messages) = store.messagesState {
                        withAnimation {
                            store.messagesState = .success(messages + [message])
                        }
                    }
                }
        case .newMessageDraftChanged:
            return HookPublisher(store.publisher.newMessageString)
                .sink { newMessage in
                    service.cacheDraft(newMessage)
                }
        }
    }
}
```

So as we can see, actions and hooks is what we use to update state.

## View

This sets up a basic chat view. We encapsulate our logic into a Store. We then interact with the store by using the `@StateStore` property wrapper. The store behaves pretty much like any `ObservableObject` which means we can observe state changes and create bindings by prefixing state properties with `$`. We trigger actions by calling `store.dispatch`. 

```swift
struct ChatView: View {
    
    @StateStore var store: Store<ChatState, ChatAction>
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    switch store.messagesState {
                 // case .loading:
                    case .success(let messages):
                        LazyVStack {
                            ForEach(messages) { message in
                                Group {
                                    switch message.from {
                                    case .me:
                                        HStack {
                                            Spacer()
                                            MessageView(text: message.text, color: .blue)
                                        }
                                    case .other:
                                        HStack {
                                            MessageView(text: message.text, color: .gray)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }

                 // case .failure(let error)
                }
                NewMessageView(message: $store.newMessageString) {
                    store.dispatch(.sendMessage)
                }
                .padding()
            }

            .task {
                await store.dispatch(.getMessages)
            }
            .navigationTitle("Conversation")
        }

    }
}

struct NewMessageView: View {
    // ..
}

struct MessageView: View {
    // ..
}
```

SwiftUI animations works out of the box. Let's add a animation for when we recieve a new message.

```swift
case .messageRecieved:
    return HookPublisher(service.receivedMessage)
	.sink { message in
	    if case .success(let messages) = store.messagesState {
		withAnimation {
		    store.messagesState = .success(messages + [message])
		}
	    }
	}
}
```

Now all we need to do is provide a service implementation and we are all set! Let's create a mock for now.

```swift
extension Array where Element == ChatState.Message {
    static let mock: [ChatState.Message] = [
        .init(from: .me, text: "Hello my friend"),
        .init(from: .other, text: "Well hello"),
        .init(from: .me, text: "Protein, iron, and calcium are some of the nutritiona benefits associated with cheeseburgers."),
    ]
}

extension ChatService {
    static var mock: Self {
        let subject = PassthroughSubject<ChatState.Message, Never>()
        return ChatService(
            getMessages: {
                try await Task.sleep(nanoseconds: 0_500_000_000)
                return .mock
            },
            sendMessage: {
                subject.send($0)
            },
            receivedMessage: subject.eraseToAnyPublisher(),
            cacheDraft: { _ in }
        )
    }
}
```

 And now we are ready to display something on the screen!

```swift
import SwiftUI
import Eazy

@main
struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView(store: Store(state: ChatState(),
                                  interactor: ChatInteractor(service: .mock)))
        }
    }
}
```

That's it! We covered the fundamentals of Eazy, keep on reading for additional info. You can find the full example [here](https://github.com/bangerang/swift-eazy/tree/main/Examples/Chat).

## Testing

Since we kept a clean interface to our dependency in the Interactor, testing our feature is easy. Eazy comes with a dedicated TestStore.

```swift
import XCTest
import Eazy
import Combine
@testable import Chat

class ChatTests: XCTestCase {
    
    @MainActor
    func testGetMessages() async {
        let store = TestStore(state: ChatState(), interactor: ChatInteractor(service: .mock))
        await store.dispatch(.getMessages)
        let expected = ChatState(messagesState: .success(.mock), newMessageString: "")
        XCTAssertEqual(store.state, expected)
    }
    
    @MainActor
    func testMessageRecieved() async {
        let subject = PassthroughSubject<ChatState.Message, Never>()
        let newMessage = ChatState.Message(from: .other, text: "Foo")
        let service = ChatService.mock(subject: subject)
        let store = await TestStore.testHook(.messageRecieved,
                                             trigger: subject.send(newMessage),
                                             state: ChatState(messagesState: .success([])),
                                             interactor: ChatInteractor(service: service))
        let expected = ChatState(messagesState: .success([newMessage]))
        XCTAssertEqual(store.state, expected)
    }
}
```

## UIKit

Eazy works great in UIKit too and comes with some convinience for assigning and bind values to views.

```swift
struct SomeState: Equatable {
    var text = "Hello"
    var isHidden = false
}

enum SomeAction: Equatable {
    case buttonTapped
}

enum SomeHook: CaseIterable {
    case textChanged
}

struct SomeInteractor: Interactor {
    func onAction(_ action: SomeAction, store: MutatingStore<SomeState, SomeAction>) async {
        switch action {
        case .buttonTapped:
            store.isHidden = !store.isHidden
        }
    }
    
    func publisher(for hook: SomeHook, store: MutatingStore<SomeState, SomeAction>) -> AnyCancellable {
        switch hook {
        case .textChanged:
            return HookPublisher(store.publisher.text)
                .map {
                    $0.count.isMultiple(of: 2)
                }
                .assign(to: \.isHidden, using: store)
        }
    }
}

class ViewController: UIViewController {
    
    let store = Store(state: SomeState(), interactor: SomeInteractor())
  
    var cancellables: Set<AnyCancellable> = []
    
  	let label = UILabel()
  
    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    lazy var hiddenView: UIView = {
        let view = UIView()
        view.backgroundColor = .red
        return view
    }()
    
    lazy var button: UIButton = {
        let button = UIButton(primaryAction: .init(handler: { [weak self] action in
            self?.store.dispatch(.buttonTapped)
        }))
        button.setTitle("Toggle", for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupBindings()
    }
    
    func setupViews() {
        // ...
    }
    
    func setupBindings() {
        textField.bind(to: \.text, using: store, storeIn: &cancellables)
        label.assign(to: \.text, using: store, storeIn: &cancellables)
        store.publisher.isHidden
            .assign(to: \.isHidden, on: hiddenView)
            .store(in: &cancellables)
    }
}
```

## Debugging

SwiftUI apps can be a bit tricky to debug. But fear not, Eazy provides a `DebugStore` to make this a bit easier.

```swift
DebugStore.enableLogging()
```

```shell
Eazy - Initial state:
ChatState(
  messagesState: ChatState.MessagesState.loading,
  newMessageString: ""
)
Eazy - Triggered action:
ChatAction.getMessages
Eazy - State changed:
  ChatState(
-   messagesState: ChatState.MessagesState.loading,
+   messagesState: ChatState.MessagesState.success(
+     [
+       [0]: ChatState.Message(
+         id: UUID(1D72C282-C057-45EA-9632-EFE8A02AA428),
+         from: ChatState.Message.From.me,
+         text: "Hello my friend"
+       ),
+       [1]: ChatState.Message(
+         id: UUID(3F410CD7-CCAF-4DEF-B7A2-1057F7083122),
+         from: ChatState.Message.From.other,
+         text: "Well hello"
+       ),
+       [2]: ChatState.Message(
+         id: UUID(3E57A986-ED89-4C29-BC22-32F885F79806),
+         from: ChatState.Message.From.me,
+         text: """
+           Protein, iron, and calcium are some of the nutritional benefits associated with cheeseburgers.
+           Salad is essentially food for rabbits, so don’t bother wasting your time.
+           """
+       )
+     ]
+   ),
    newMessageString: ""
  )
```

We can also route the output to our own output stream, makes it trivial to write the output to a file for instance.

```swift
DebugStore.print = { message in
    // Handle message
}
```

## Cancel actions

If we conform to `CancellableAction`any previous actions gets cancelled.

```swift
enum CatSearchAction: Equatable, CancellableAction {
    case searchCat(String)
    
    var cancelIdentifier: String? {
        switch self {
        case .searchCat:
            return "searchCat"
        }
    }
}

struct CatSearchInteractor: Interactor {
  	// ...
    func onAction(_ action: CatSearchAction, store: MutatingStore<CatSearchState, CatSearchAction>) async {
        switch action {
        case .searchCat(let query):
            do {
                store.cats = try await service.search(cats: query)
            } catch {
                if !Task.isCancelled {
                    store.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

## Threading

Store runs on the main thread and is labeled to use the `@MainActor`. This means that the compiler will mostly help us enforce that we are calling the store from the same context. However, the compiler is unable to enforce this for Combine publishers so be careful on which scheduler you deliver your output on. We need to make sure that our publishers eventually publish their output on the main queue.

```swift
    func publisher(for hook: SomeHook, store: MutatingStore<SomeState, SomeAction>) -> AnyCancellable {
        switch hook {
        case .someHook:
            return HookPublisher(service.somePublisherThatRunsInADifferentContext)
          	.receive(on: DispatchQueue.main)
                .sink { _ in
			// ...
                }
        }
    }
```

## Combine extensions

Eazy provides some nice convience extensions to assign values and actions from hook publishers. See Cocktail and Form examples for more info.

```swift
case .signUpStateChanged:
    return HookPublisher(store.publisher.signUpState)
	.compactMap {
	    if case .failure(let error) = $0 {
		return error
	    }
	    return nil
	}
	.assign(to: \.notValidText, using: store, animation: .default)
```

## Installation

Add the package through Xcode by selecting **File/Add packages...** or add this to your `Package.swift`

```swift
    dependencies: [
        .package(name: "Eazy", url: "https://github.com/bangerang/swift-eazy.git", .upToNextMajor(from: "0.0.1"))
    ]
```

## Documentation

Is available [here](https://bangerang.github.io/swift-eazy/documentation/eazy).

## Examples

Interested in seeing more examples of Eazy in action? You'll find all the examples [here](https://github.com/bangerang/swift-eazy/tree/main/Examples).

## Credits

A huge thanks to Point-Free and their work with [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)  for being a big inspiration when building this library.
