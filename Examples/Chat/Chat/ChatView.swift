import SwiftUI
import Combine
import Eazy

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

enum ChatAction: Equatable {
    case getMessages
    case sendMessage
}

enum ChatHook: CaseIterable {
    case messageRecieved
    case newMessageChanged
}

struct ChatService {
    let getMessages: () async throws -> [ChatState.Message]
    let sendMessage: (ChatState.Message) async -> Void
    let receivedMessage: AnyPublisher<ChatState.Message, Never>
    let cacheDraft: (String) -> Void
}

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
        case .newMessageChanged:
            return HookPublisher(store.publisher.newMessageString)
                .sink { newMessage in
                    service.cacheDraft(newMessage)
                }
        }
    }
}

struct ChatView: View {
    
    @StateStore var store: Store<ChatState, ChatAction>
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    switch store.messagesState {
                    case .loading:
                        ProgressView()
                            .padding()
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

                    case .failure(let error):
                        Text(error)
                            .padding()
                    }
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
    @Binding var message: String
    var didPressSend: () -> Void
    var body: some View {
        HStack {
            TextField("New message", text: $message)
            Button {
                didPressSend()
            } label: {
                Label("Send", systemImage: "paperplane")
            }

        }
    }
}

struct MessageView: View {
    let text: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(text)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(16)
                .background(color)
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(store: Store(state: ChatState(messagesState: .success(.mock)),
                              interactor: ChatInteractor(service: .mock)))
    }
}

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
    static func mock(subject: PassthroughSubject<ChatState.Message, Never>) -> Self {
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

