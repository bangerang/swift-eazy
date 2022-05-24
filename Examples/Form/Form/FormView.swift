import SwiftUI
import Eazy
import Combine

struct SignupService {
    var signUp: (String, String) async throws -> String
}

struct FormState: Equatable {
    enum SignupState: Equatable {
        case idle
        case loading
        case success(String)
        case failure(String)
    }
    
    enum PasswordStrengthLevel: CGFloat, Equatable {
        case `none` = 4
        case weak = 3
        case medium = 2
        case good = 1
    }
    
    var email: String = ""
    var password: String = ""
    var repeatPassword: String = ""
    var notValidText: String = ""
    var passswordStrengthLevel: PasswordStrengthLevel = .none
    var passwordIsValid: Bool = false
    var signUpEnabled: Bool = false
    var signUpState: SignupState = .idle
}

enum FormAction: Equatable {
    case signUp
}

enum FormHook: CaseIterable {
    case passwordChanged
    case signUpStateChanged
    case anyPasswordChanged
    case passwordValidOrEmailChanged
}

struct FormInteractor: Interactor {
    
    let service: SignupService
    
    func onAction(_ action: FormAction, store: MutatingStore<FormState, FormAction>) async {
        switch action {
        case .signUp:
            store.signUpState = .loading
            do {
                let success = try await service.signUp(store.email, store.password)
                store.signUpState = .success(success)
            } catch {
                store.signUpState = .failure(error.localizedDescription) 
            }
        }
    }
    
    func publisher(for hook: FormHook, store: MutatingStore<FormState, FormAction>) -> AnyCancellable {
        switch hook {
        case .passwordChanged:
            return HookPublisher(store.publisher.password)
                .compactMap { password in
                    var value = FormState.PasswordStrengthLevel.none.rawValue
                    if hasNumber(string: password) {
                        value -= 1
                    }
                    if hasLetter(string: password) {
                        value -= 1
                    }
                    if isLongEnough(string: password) {
                        value -= 1
                    }
                    if value == 4 {
                        return FormState.PasswordStrengthLevel.none
                    } else {
                        return FormState.PasswordStrengthLevel(rawValue: value)
                    }
                }
                .assign(to: \.passswordStrengthLevel, using: store, animation: .custom(.spring()))
        case .signUpStateChanged:
            return HookPublisher(store.publisher.signUpState)
                .compactMap {
                    if case .failure(let error) = $0 {
                        return error
                    }
                    return nil
                }
                .assign(to: \.notValidText, using: store)
        case .anyPasswordChanged:
            return HookPublisher(Publishers.CombineLatest(store.publisher.password, store.publisher.repeatPassword))
                .map { password, repeatPassword in
                    return password.count > 0 && password == repeatPassword
                }
                .assign(to: \.passwordIsValid, using: store)
        case .passwordValidOrEmailChanged:
            return HookPublisher(Publishers.CombineLatest(store.publisher.passwordIsValid, store.publisher.email))
                .map { passwordIsValid, email in
                    return passwordIsValid && validateEmail(email)
                }
                .assign(to: \.signUpEnabled, using: store)
        }
    }
    
    private func validateEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format:"SELF MATCHES %@", regex)
        return predicate.evaluate(with: email)
    }
    
    private func hasNumber(string: String) -> Bool {
        return string.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    private func hasLetter(string: String) -> Bool {
        return string.rangeOfCharacter(from: .letters) != nil
    }
    
    private func isLongEnough(string: String) -> Bool {
        return string.count >= 8
    }
}

struct FormView: View {
    @StateStore var store: Store<FormState, FormAction>
    
    var body: some View {
        NavigationView {
            Group {
                switch store.signUpState {
                case .loading:
                    ProgressView()
                case .failure, .idle:
                    Form {
                        Section {
                            TextField("Email", text: $store.email)
                        }
                        Section {
                            SecureField("Password", text: $store.password)
                            SecureField("Repeat password", text: $store.repeatPassword)
                            
                            if store.passswordStrengthLevel != .none {
                                HStack(alignment: .center) {
                                    if store.passswordStrengthLevel != .none {
                                        Text("Strength")
                                            .transition(.asymmetric(insertion: .opacity,
                                                                    removal: .move(edge: .leading)
                                                                        .combined(with: .opacity)))
                                    }
                                    GeometryReader { proxy in
                                        Rectangle()
                                            .foregroundColor(getStrengthColor())
                                            .frame(width: store.passswordStrengthLevel == .none ? 40 : proxy.size.width / store.passswordStrengthLevel.rawValue, height: 10)
                                            .cornerRadius(8)
                                            .scaleEffect(store.passswordStrengthLevel == .none ? CGSize(width: 0, height: 1) : CGSize(width: 1, height: 1), anchor: .leading)
                                        
                                    }
                                    .offset(y: 12)
                                }
                            }

                        }
                        
                        Section {
                            Button("Sign up") {
                                store.dispatch(.signUp)
                            }.disabled(!store.signUpEnabled)
                        } footer: {
                            Text(store.notValidText)
                                .foregroundColor(.red)
                        }
                        
                    }
                case .success(let success):
                    Text(success)
                }
            }
            .navigationTitle("Sign up")
        }
    }
    
    func getStrengthColor() -> Color {
        switch store.passswordStrengthLevel {
        case .none:
            return .red
        case .weak:
            return .red
        case .medium:
            return .yellow
        case .good:
            return .green
        }
    }
}

extension SignupService {
    static var mock: SignupService {
        return .init(signUp: { email, password in
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return "Yey!"
        })
    }
}

struct FormView_Previews: PreviewProvider {
    static var previews: some View {
        FormView(store: Store(state: FormState(),
                              interactor: FormInteractor(service: .mock)))
    }
}
