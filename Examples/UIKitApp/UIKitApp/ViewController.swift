import UIKit
import Eazy
import Combine

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
    
    let store: Store<SomeState, SomeAction>
    
    var cancellables: Set<AnyCancellable> = []
    
    let label = UILabel()

    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    lazy var hiddenView: UIView = {
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
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
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        return stackView
    }()
    
    required init?(coder: NSCoder) {
        store = Store(state: SomeState(), interactor: SomeInteractor())
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupBindings()
    }
    
    func setupViews() {
        view.addSubview(hiddenView)
        hiddenView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hiddenView.widthAnchor.constraint(equalToConstant: 100),
            hiddenView.heightAnchor.constraint(equalToConstant: 100),
            hiddenView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hiddenView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(textField)
        stackView.addArrangedSubview(button)
        stackView.addArrangedSubview(label)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 200),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    func setupBindings() {
        textField.bind(to: \.text, using: store, storeIn: &cancellables)
        label.assign(to: \.text, using: store, storeIn: &cancellables)
        store.publisher.isHidden
            .weakAssign(to: \.isHidden, on: hiddenView)
            .store(in: &cancellables)
    }
}
