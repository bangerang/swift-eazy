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
