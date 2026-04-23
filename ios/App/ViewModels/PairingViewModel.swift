import Foundation

@MainActor
final class PairingViewModel: ObservableObject {
    @Published var pair: Pair?
    @Published var inviteCode = ""
    @Published var generatedInviteCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService.shared

    func loadPair() async {
        do {
            pair = try await service.fetchMyPair()
            syncWidgetNoPairIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createInviteCode() async {
        isLoading = true
        defer { isLoading = false }
        do {
            generatedInviteCode = try await service.createPairInviteCode()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinPair() async {
        guard !inviteCode.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await service.joinPair(inviteCode: inviteCode)
            pair = try await service.fetchMyPair()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlinkPair() async {
        do {
            try await service.unlinkPair()
            pair = nil
            WidgetCacheStore.save(.noPair)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncWidgetNoPairIfNeeded() {
        if pair == nil {
            WidgetCacheStore.save(.noPair)
        }
    }
}
