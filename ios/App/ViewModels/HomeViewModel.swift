import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var latestMoment: Moment?
    @Published var cachedWidgetMoment: WidgetMoment?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService.shared
    private var realtimeTask: Task<Void, Never>?

    func loadCached() {
        let state = WidgetCacheStore.read()
        if case .moment(let widgetMoment) = state {
            cachedWidgetMoment = widgetMoment
        } else {
            cachedWidgetMoment = nil
        }
    }

    func refresh(pairID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            latestMoment = try await service.fetchLatestMomentFromPartner(pairID: pairID)
            if let moment = latestMoment {
                let widgetMoment = WidgetMoment(
                    text: moment.text,
                    imageURL: moment.imageURL,
                    createdAt: moment.createdAt
                )
                WidgetCacheStore.save(.moment(widgetMoment))
                cachedWidgetMoment = widgetMoment
            } else {
                WidgetCacheStore.save(.noMoment)
                cachedWidgetMoment = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            loadCached()
        }
    }

    // Called by AppDelegate for background fetch and silent push — no UI state side-effects.
    static func backgroundRefresh(pairID: UUID) async {
        do {
            let moment = try await SupabaseService.shared.fetchLatestMomentFromPartner(pairID: pairID)
            if let moment {
                WidgetCacheStore.save(.moment(WidgetMoment(
                    text: moment.text,
                    imageURL: moment.imageURL,
                    createdAt: moment.createdAt
                )))
            }
        } catch {
            // Background refresh best-effort; errors are silent.
        }
    }

    func subscribeToMoments(pairID: UUID) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let stream = await service.partnerMomentStream(pairID: pairID)
            for await _ in stream {
                guard !Task.isCancelled else { break }
                await refresh(pairID: pairID)
            }
        }
    }

    func unsubscribe() {
        realtimeTask?.cancel()
        realtimeTask = nil
        Task { await service.unsubscribeFromPartnerMoments() }
    }
}
