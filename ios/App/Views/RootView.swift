import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var pairingViewModel = PairingViewModel()
    @AppStorage("widgetOnboardingDone") private var widgetOnboardingDone = false

    var body: some View {
        Group {
            if !authViewModel.isReady {
                LoginView(viewModel: authViewModel)
            } else if !widgetOnboardingDone {
                WidgetOnboardingView { widgetOnboardingDone = true }
            } else if let pair = pairingViewModel.pair {
                HomeView(pair: pair, pairingViewModel: pairingViewModel)
            } else {
                PairingView(viewModel: pairingViewModel)
            }
        }
        .task(id: authViewModel.isReady) {
            if authViewModel.isReady {
                await pairingViewModel.loadPair()
            }
        }
    }
}
