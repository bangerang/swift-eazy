import SwiftUI
import Eazy
import Combine

@main
struct FormApp: App {
    var body: some Scene {
        WindowGroup {
            FormView(store: Store(state: FormState(),
                                  interactor: FormInteractor(service: .mock)))
                .onAppear {
                    DebugStore.enableLogging()
                }
        }
    }
}
