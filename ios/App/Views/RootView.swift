import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var pairingViewModel = PairingViewModel()

    var body: some View {
        Group {
            if !authViewModel.isReady {
                LoginView(viewModel: authViewModel)
            } else if let pair = pairingViewModel.pair {
                HomeView(pair: pair, pairingViewModel: pairingViewModel)
            } else {
                PairingView(viewModel: pairingViewModel)
                    .task { await pairingViewModel.loadPair() }
            }
        }
        .task(id: authViewModel.isReady) {
            if authViewModel.isReady {
                await pairingViewModel.loadPair()
            }
        }
    }
}
