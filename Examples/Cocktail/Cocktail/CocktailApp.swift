import SwiftUI
import Eazy
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DebugStore.enableLogging()
        return true
    }
}

let api = CocktailAPI()

let service = CocktailService(cocktailProvider: CocktailProvider(searchCocktail: { string in
    return try await api.searchCocktail(query: string)
}))

@main
struct CocktailApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            CocktailSearchView(store: Store(state: CocktailSearchState(),
                                            interactor: CocktailSearchInteractor(service: service)))
        }
    }
}
