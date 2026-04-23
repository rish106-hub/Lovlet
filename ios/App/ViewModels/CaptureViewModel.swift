import Foundation
import UIKit

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var text = ""
    @Published var isUploading = false
    @Published var errorMessage: String?
    @Published var uploadSuccess = false

    private let service = SupabaseService.shared

#if DEBUG
    private static let dummyPairID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
#endif

    func uploadMoment(image: UIImage, pairID: UUID) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isUploading = true
        defer { isUploading = false }

#if DEBUG
        if pairID == Self.dummyPairID {
            try? await Task.sleep(for: .milliseconds(600))
            text = ""
            uploadSuccess = true
            return
        }
#endif

        do {
            try await service.uploadMoment(image: image, text: text, pairID: pairID)
            text = ""
            uploadSuccess = true
        } catch {
            do {
                try await service.uploadMoment(image: image, text: text, pairID: pairID)
                text = ""
                uploadSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
