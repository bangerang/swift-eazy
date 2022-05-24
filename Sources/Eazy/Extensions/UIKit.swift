//
//  File.swift
//  
//
//  Created by Johan Thorell on 2022-04-30.
//

import Foundation
import SwiftUI
import Combine

#if os(iOS)
public extension UITextField {
    func bind<State, Action>(to keyPath: WritableKeyPath<State, String>, using store: Store<State, Action>, storeIn cancellables: inout Set<AnyCancellable>) {
        self.text = store.state[keyPath: keyPath]
        
        let binding = store.binder.binding(for: keyPath)
        let publisher = store.publisher.publisher(for: keyPath)
        publisher.sink { [weak self] value in
            self?.text = value
        }
        .store(in: &cancellables)
        
        addAction(UIAction(handler: { action in
            guard let textField = action.sender as? UITextField,
                  let text = textField.text else {
                      return
                  }
            binding.wrappedValue = text
        }), for: .editingChanged)
    }
}

public extension UISwitch {
    func bind<State, Action>(to keyPath: WritableKeyPath<State, Bool>, using store: Store<State, Action>, storeIn cancellables: inout Set<AnyCancellable>) {
        self.isOn = store.state[keyPath: keyPath]
        let binding = store.binder.binding(for: keyPath)
        let publisher = store.publisher.publisher(for: keyPath)
        publisher.sink { [weak self] value in
            self?.isOn = value
        }
        .store(in: &cancellables)
        
        addAction(UIAction(handler: { action in
            guard let aSwitch = action.sender as? UISwitch else {
                return
            }
            binding.wrappedValue = aSwitch.isOn
        }), for: .valueChanged)
    }
}

public extension UILabel {
    func assign<State, Action>(to keyPath: KeyPath<State, String>, using store: Store<State, Action>, storeIn cancellables: inout Set<AnyCancellable>) {
        self.text = store.state[keyPath: keyPath]
        let publisher = store.publisher.publisher(for: keyPath)
        publisher.sink { [weak self] value in
            self?.text = value
        }
        .store(in: &cancellables)
    }
}
#endif
