import Foundation
import UIKit
import SwiftUI
import Eazy
import EngineeringMode

@MainActor
class SettingsCoordinator {
    
    let navigationController: UINavigationController
    
    var engineeringModeCoordinator: EngineeringModeCoordinator?
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let view = SettingsView(store: self.makeSettingsStore())
        let vc = UIHostingController(rootView: view)
        vc.title = "Settings"
        navigationController.viewControllers = [vc]
    }
    
    func makeSettingsStore() -> Store<SettingsState, SettingsAction> {
        return Store(state: .init(),
                     interactor: SettingsInteractor(service: .mock,
                                                    coordinator: self))
    }
    
    func settingsDidPressEngineeringMode() {
        let coordinator = EngineeringModeCoordinator(navigationController: navigationController)
        engineeringModeCoordinator = coordinator
        engineeringModeCoordinator?.start(state: EngineeringModeState(userID: "2451"), service: .mock)
    }
}
