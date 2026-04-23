import SwiftUI

struct LoginView: View {
    @StateObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Preparing your device")
                .font(.title2.bold())

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                    Task { await viewModel.bootstrapDeviceSession() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .task {
            await viewModel.bootstrapDeviceSession()
        }
    }
}
