import SwiftUI

@main
struct ManagementQuizStemApp: App {
    @StateObject private var authSession = AuthSessionController()

    init() {
        FirebaseConfigurator.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authSession)
        }
    }
}
