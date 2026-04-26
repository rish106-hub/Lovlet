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
            // Step 1: upload image — only ever done once.
            let imagePath = try await service.uploadMomentImage(image, pairID: pairID)

            // Step 2: save DB record — retry once on failure (image already uploaded).
            do {
                try await service.saveMomentRecord(imagePath: imagePath, text: text)
            } catch {
                try await service.saveMomentRecord(imagePath: imagePath, text: text)
            }

            text = ""
            uploadSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
