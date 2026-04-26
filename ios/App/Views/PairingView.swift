import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: PairingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect with your partner")
                .font(.title3.bold())

            if let code = viewModel.generatedInviteCode {
                Text("Invite code: \(code)")
                    .font(.title2.monospaced())
            }

            Button("Generate Invite Code") {
                Task { await viewModel.createInviteCode() }
            }
            .buttonStyle(.borderedProminent)

            TextField("Enter invite code", text: $viewModel.inviteCode)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)

            Button(viewModel.isLoading ? "Joining..." : "Join Pair") {
                Task { await viewModel.joinPair() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading || viewModel.inviteCode.isEmpty)

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }

#if DEBUG
            Divider()
            Button("⚡ Skip — Dev Only") {
                viewModel.useDummyPair()
            }
            .foregroundStyle(.orange)
#endif
        }
        .padding()
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}
