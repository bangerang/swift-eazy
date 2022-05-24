//
//  UIKitTests.swift
//  
//
//  Created by Johan Thorell on 2022-05-15.
//

import XCTest
import Combine
@testable import Eazy

class UIKitTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable> = []
    
    @MainActor
    func testBindTextField() {
        let store = Store<TestState, EmptyAction>(state: TestState(foo: "foo", bar: 123))
        let textField = UITextField()
        textField.bind(to: \.foo, using: store, storeIn: &cancellables)
        XCTAssertEqual(textField.text, store.foo)
        store.binder.foo.wrappedValue = "bar"
        XCTAssertEqual(textField.text, "bar")
        textField.text = "bond"
        textField.sendActions(for: .editingChanged)
        XCTAssertEqual(store.foo, "bond")
    }

    @MainActor
    func testBindSwitch() {
        struct State: Equatable { var bool = true }
        let store = Store<State, EmptyAction>(state: State())
        let sw = UISwitch()
        sw.bind(to: \.bool, using: store, storeIn: &cancellables)
        XCTAssertEqual(sw.isOn, store.bool)
        store.binder.bool.wrappedValue = false
        XCTAssertEqual(sw.isOn, false)
        sw.isOn = true
        sw.sendActions(for: .valueChanged)
        XCTAssertEqual(store.bool, true)
    }
    
    @MainActor
    func testAssignLabel() {
        let store = Store<TestState, EmptyAction>(state: TestState(foo: "foo", bar: 123))
        let label = UILabel()
        label.assign(to: \.foo, using: store, storeIn: &cancellables)
        XCTAssertEqual(label.text, store.foo)
        store.binder.foo.wrappedValue = "called"
        XCTAssertEqual(label.text, "called")
    }
}
