import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var latestMoment: Moment?
    @Published var cachedWidgetMoment: WidgetMoment?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService.shared

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
                WidgetCacheStore.save(
                    .moment(
                        WidgetMoment(
                            text: moment.text,
                            imageURL: moment.imageURL,
                            createdAt: moment.createdAt
                        )
                    )
                )
                cachedWidgetMoment = WidgetMoment(
                    text: moment.text,
                    imageURL: moment.imageURL,
                    createdAt: moment.createdAt
                )
            } else {
                WidgetCacheStore.save(.noMoment)
                cachedWidgetMoment = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            // Keep showing cached moment in poor network conditions.
            loadCached()
        }
    }
}
