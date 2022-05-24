import UIKit
import SwiftUI
import Eazy

@MainActor
public class EngineeringModeCoordinator {
    
    let navigationController: UINavigationController
    
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    public func start(state: EngineeringModeState, service: EngineeringModeService) {
        let store = Store(state: state,
                          interactor: EngineeringModeInteractor(service: service,
                                                                coordinator: self))
        let vc = UIHostingController(rootView: EngineeringModeView(store: store))
        vc.title = "Engineering mode"
        navigationController.pushViewController(vc, animated: true)
    }
    
    func shareLog(_ url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        navigationController.present(activityViewController, animated: true)
    }
}
