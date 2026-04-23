import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service = SupabaseService.shared

    func bootstrapDeviceSession() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.ensureAnonymousSession()
            try await service.ensureUserRow()
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
            isReady = false
        }
    }
}
