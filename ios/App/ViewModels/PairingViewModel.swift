import Foundation

@MainActor
final class PairingViewModel: ObservableObject {
    @Published var pair: Pair?
    @Published var inviteCode = ""
    @Published var generatedInviteCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService.shared
    private var pollTask: Task<Void, Never>?

    func loadPair() async {
        do {
            pair = try await service.fetchMyPair()
            if pair != nil {
                stopPolling()
                cachePairIDForBGRefresh(pair!.id)
            }
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
            startPollingForPair()
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
            clearCachedPairID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPollingForPair() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self else { break }
                await self.loadPair()
                if self.pair != nil { break }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func syncWidgetNoPairIfNeeded() {
        if pair == nil {
            WidgetCacheStore.save(.noPair)
        }
    }

    private func cachePairIDForBGRefresh(_ id: UUID) {
        UserDefaults(suiteName: SharedConstants.appGroupID)?
            .set(id.uuidString, forKey: "cached_pair_id")
    }

    private func clearCachedPairID() {
        UserDefaults(suiteName: SharedConstants.appGroupID)?
            .removeObject(forKey: "cached_pair_id")
    }

#if DEBUG
    func useDummyPair() {
        pair = Pair(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            user1ID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            user2ID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            createdAt: Date()
        )
    }
#endif
}
