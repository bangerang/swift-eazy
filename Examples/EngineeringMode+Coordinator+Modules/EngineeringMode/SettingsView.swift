import SwiftUI
import Eazy
import Combine

enum Languange: String, CaseIterable {
    case en = "English"
    case fr = "French"
}

struct SettingsState: Equatable {
    var language = Languange.en
    var pushEnabled = false
}

enum SettingsAction: Equatable {
    case languageSelected(Languange)
    case pushTapped
    case engineeringModeTapped
}

enum SettingsHook: CaseIterable {
    case languageChanged
    case pushChanged
}

struct SettingsService {
    let changeLanguage: (_ language: Languange) async -> Void
    let setPushEnabled: (_ enabled: Bool) async -> Void
    let langageChanged: AnyPublisher<Languange, Never>
    let pushChanged: AnyPublisher<Bool, Never>
}

struct SettingsInteractor: Interactor {
    
    let service: SettingsService
    let coordinator: SettingsCoordinator
    
    func onAction(_ action: SettingsAction, store: MutatingStore<SettingsState, SettingsAction>) async {
        switch action {
        case .engineeringModeTapped:
            coordinator.settingsDidPressEngineeringMode()
        case .pushTapped:
            await service.setPushEnabled(!store.pushEnabled)
        case .languageSelected(let language):
            await service.changeLanguage(language)
        }
    }
    
    func publisher(for hook: SettingsHook, store: MutatingStore<SettingsState, SettingsAction>) -> AnyCancellable {
        switch hook {
        case .languageChanged:
            return HookPublisher(service.langageChanged)
                .assign(to: \.language, using: store)
        case .pushChanged:
            return HookPublisher(service.pushChanged)
                .assign(to: \.pushEnabled, using: store, animation: .default)
        }
    }
}

struct SettingsView: View {
    
    @StateStore var store: Store<SettingsState, SettingsAction>
    
    var body: some View {
        List {
            Section {
                Toggle("Push enabled", isOn: $store.pushEnabled)
                HStack {
                    Text("Language")
                    Spacer()
                    Menu {
                        Picker(selection: $store.binding(get: \.language,
                                                         action: SettingsAction.languageSelected),
                               label: Text("Language")) {
                            ForEach(Languange.allCases, id: \.self) { language in
                                Text(language.rawValue)
                            }
                        }
                    } label: {
                        Text(store.language.rawValue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            
            Section {
                Button("Engineering mode") {
                    store.dispatch(.engineeringModeTapped)
                }
            }


        }
    }
}

extension SettingsService {
    static var mock: SettingsService {
        let languageSubject = PassthroughSubject<Languange, Never>()
        let pushSubject = PassthroughSubject<Bool, Never>()
        
        let service = SettingsService(
            changeLanguage: { language in
                languageSubject.send(language)
            },
            setPushEnabled: { pushEnabled in
                pushSubject.send(pushEnabled)
            },
            langageChanged: languageSubject.eraseToAnyPublisher(),
            pushChanged: pushSubject.eraseToAnyPublisher()
        )
        
        return service
    }
}
