import Foundation
import UIKit

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var text = ""
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let service = SupabaseService.shared

    func uploadMoment(image: UIImage, pairID: UUID) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            try await service.uploadMoment(image: image, text: text, pairID: pairID)
            text = ""
        } catch {
            // Lightweight retry once for transient failures.
            do {
                try await service.uploadMoment(image: image, text: text, pairID: pairID)
                text = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
