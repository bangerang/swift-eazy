import Foundation
import CustomDump

public struct DebugStore {
    
    /// The default handler for managing log output.
    public static var print: (String) -> Void = { message in
        if NSClassFromString("XCTest") == nil {
            Swift.print(message)
        }
    }
    
    enum LogEnabledType {
        case none
        case global
        case included([Any.Type])
        case excluded([Any.Type])
        
        func isEnabled(type: Any.Type) -> Bool {
            if case .included(let i) = self {
                return i.contains(where: { type == $0 })
            }
            if case .global = self {
                return true
            }
            return false
        }
    }
    
    static private(set) var logEnabledType: LogEnabledType = .none
    
    public enum FilterOption {
        case include([Any.Type])
        case exclude([Any.Type])
    }
    
    /// Enables logging
    ///
    /// - Parameters:
    ///    - filter: Choose to whether inlude or exclude state
    ///```swift
    /// DebugStore.enableLogging(.include([MyState.self]))
    ///```
    public static func enableLogging(_ filter: FilterOption? = nil) {
        if let filter = filter {
            switch filter {
            case .include(let included):
                logEnabledType = .included(included)
            case .exclude(let excluded):
                logEnabledType = .excluded(excluded)
            }
        } else {
            logEnabledType = .global
        }
    }
    
    public static func disableLogging() {
        logEnabledType = .none
    }
}

struct LoggerProxy {
    static func log<T>(from type: T.Type, logAction: @autoclosure () -> Void) {
        switch DebugStore.logEnabledType {
        case .none:
            break
        case .global:
            logAction()
        case .included(let included):
            if included.contains(where: { type == $0}) {
                logAction()
            }
        case .excluded(let excluded):
            if !excluded.contains(where: { type == $0 }) {
                logAction()
            }
        }
    }
}

struct Logger {
    
    static private let queue = DispatchQueue(label: "Eazy Logger", qos: .background)
    
    static func logInitialState<T>(_ value: T, print: @escaping (String) -> Void) {
        queue.async {
            var output = ""
            customDump(value, to: &output)
            let message = "Eazy - Initial state:\n\(output)"
            print(message)
        }
    }
    
    static func logBindingString(_ action: String, print: @escaping (String) -> Void) {
        queue.async {
            let message = "Eazy - Triggered action:\n\(action)"
            print(message)
        }
    }
    
    static func logAction<Action>(_ action: Action, print: @escaping (String) -> Void) {
        queue.async {
            var output = ""
            customDump(action, to: &output)
            let message = "Eazy - Triggered action:\n\(output)"
            print(message)
        }
    }
    
    static func logHook<Hook, T>(_ hook: Hook, _ value: T, print: @escaping (String) -> Void) {
        queue.async {
            var valueOutput = ""
            customDump(value, to: &valueOutput)
            let message = "Eazy - Hook fired:\n\(hook) \(valueOutput)"
            print(message)
        }
    }
    
    static func logStateChange<T>(old: T?, new: T, print: @escaping (String) -> Void) {
        queue.async {
            guard let old = old else {
                return
            }
            if let output = diff(old, new).map({ "\($0)\n" }) {
                let message = "Eazy - State changed:\n" + output
                print(message)
            }
        }
    }
}
