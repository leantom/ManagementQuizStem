import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var authSession: AuthSessionController

    var body: some View {
        Group {
            if authSession.isReady {
                AdminShellView()
            } else if authSession.isLoading {
                AdminAuthLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AdminSignInView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            authSession.start()
        }
    }
}
