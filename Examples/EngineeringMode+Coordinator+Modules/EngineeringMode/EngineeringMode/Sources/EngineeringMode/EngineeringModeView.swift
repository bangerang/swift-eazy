import SwiftUI
import Eazy
import Combine

public struct EngineeringModeState: Equatable {
    public var userID = ""
    public var loggingEnabled = false
    public init(userID: String = "", loggingEnabled: Bool = false) {
        self.userID = userID
        self.loggingEnabled = loggingEnabled
    }
}

public enum EngineeringModeAction: Equatable {
    case userIDTapped
    case setLoggingEnabled(Bool)
    case clearLog
    case exportLog
}

public enum EngineeringHook: CaseIterable {
    case loggingEnabledChanged
}

public struct EngineeringModeService {
    public let setLoggingEnabled: (_ enabled: Bool) -> Void
    public let loggingEnabledChanged: AnyPublisher<Bool, Never>
    public let clearLog: () -> Void
    public let exportLog: () async -> URL
    
    public init(setLoggingEnabled: @escaping (Bool) -> Void,
                loggingEnabledChanged: AnyPublisher<Bool, Never>,
                clearLog: @escaping () -> Void,
                exportLog: @escaping () async -> URL) {
        self.setLoggingEnabled = setLoggingEnabled
        self.loggingEnabledChanged = loggingEnabledChanged
        self.clearLog = clearLog
        self.exportLog = exportLog
    }
}

public struct EngineeringModeInteractor: Interactor {
    
    let service: EngineeringModeService
    let coordinator: EngineeringModeCoordinator
    
    public func onAction(_ action: EngineeringModeAction, store: MutatingStore<EngineeringModeState, EngineeringModeAction>) async {
        switch action {
        case .userIDTapped:
            UIPasteboard.general.string = store.userID
        case .setLoggingEnabled(let enabled):
            service.setLoggingEnabled(enabled)
        case .clearLog:
            service.clearLog()
        case .exportLog:
            let url = await service.exportLog()
            coordinator.shareLog(url)
        }
    }
    
    public func publisher(for hook: EngineeringHook, store: MutatingStore<EngineeringModeState, EngineeringModeAction>) -> AnyCancellable {
        switch hook {
        case .loggingEnabledChanged:
            return HookPublisher(service.loggingEnabledChanged)
                .assign(to: \.loggingEnabled, using: store, animation: .default)
        }
    }
}

struct EngineeringModeView: View {
    
    @StateStore var store: Store<EngineeringModeState, EngineeringModeAction>
    
    var body: some View {
        List {
            Text(store.userID)
                .onTapGesture {
                    store.dispatch(.userIDTapped)
                }
            Toggle("Logging enabled", isOn: $store.binding(get: \.loggingEnabled,
                                                           action: EngineeringModeAction.setLoggingEnabled))
            if store.loggingEnabled {
                Button("Export") {
                    store.dispatch(.exportLog)
                }
                Button("Clear") {
                    store.dispatch(.clearLog)
                }
            }
        }
    }
}

public extension EngineeringModeService {
    static var mock: EngineeringModeService {
        let loggingSubject = PassthroughSubject<Bool, Never>()
        
        let service = EngineeringModeService(
            setLoggingEnabled: {
                loggingSubject.send($0)
            },
            loggingEnabledChanged: loggingSubject.eraseToAnyPublisher(),
            clearLog: {
                
            },
            exportLog: {
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentsDirectory = paths[0]
                let fileName = "\(documentsDirectory)/app.log"
                let content = "Hello World"
                try? content.write(toFile: fileName, atomically: true, encoding: .utf8)
                return URL(fileURLWithPath: fileName)
            })
        
        return service
    }
}
