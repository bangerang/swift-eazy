import SwiftUI
import Eazy

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DebugStore.enableLogging()
        return true
    }
}

@main
struct ChatApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ChatView(store: Store(state: ChatState(),
                                  interactor: ChatInteractor(service: .mock)))
        }
    }
}
