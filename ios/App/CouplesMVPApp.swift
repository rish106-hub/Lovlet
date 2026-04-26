import SwiftUI

@main
struct CouplesMVPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                appDelegate.scheduleAppRefresh()
            }
        }
    }
}
