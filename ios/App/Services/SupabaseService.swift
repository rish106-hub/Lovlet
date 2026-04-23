import Foundation
import Supabase
import UIKit

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }

    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Device Session (Anonymous Auth)
    func ensureAnonymousSession() async throws {
        if client.auth.currentSession != nil {
            return
        }
        _ = try await client.auth.signInAnonymously()
    }

    func ensureUserRow() async throws {
        guard let userID = currentUserID else { return }
        struct UserInsert: Encodable { let id: UUID }
        try await client.database
            .from("users")
            .upsert(UserInsert(id: userID), onConflict: "id")
            .execute()
    }

    // MARK: - Pairing
    func createPairInviteCode() async throws -> String {
        let code: String = try await client.database.rpc("create_pair").execute().value
        return code
    }

    func joinPair(inviteCode: String) async throws -> UUID {
        let pairID: UUID = try await client.database
            .rpc("join_pair", params: ["invite_code": inviteCode])
            .execute()
            .value
        return pairID
    }

    func unlinkPair() async throws {
        _ = try await client.database.rpc("unlink_pair").execute()
    }

    func fetchMyPair() async throws -> Pair? {
        let pairs: [Pair] = try await client.database
            .from("pairs")
            .select()
            .limit(1)
            .execute()
            .value
        return pairs.first
    }

    // MARK: - Moments
    func uploadMoment(image: UIImage, text: String, pairID: UUID) async throws {
        guard currentUserID != nil else { throw URLError(.userAuthenticationRequired) }
        guard let compressed = ImageCompression.compressedJPEGData(image) else {
            throw URLError(.cannotEncodeContentData)
        }

        let fileName = "\(pairID.uuidString)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(AppConfig.momentsBucket)
            .upload(path: fileName, file: compressed, options: .init(contentType: "image/jpeg"))
        _ = pairID
        _ = try await client.database
            .rpc("upload_moment", params: ["image_path": fileName, "message": text])
            .execute()
    }

    func fetchLatestMomentFromPartner(pairID: UUID) async throws -> Moment? {
        let moments: [Moment] = try await client.database
            .rpc("fetch_latest_moment", params: ["target_pair_id": pairID.uuidString])
            .execute()
            .value
        guard let moment = moments.first else { return nil }
        let signedURL = try await client.storage
            .from(AppConfig.momentsBucket)
            .createSignedURL(path: moment.imageURL, expiresIn: 60 * 60 * 24)
        return Moment(
            id: moment.id,
            pairID: moment.pairID,
            senderID: moment.senderID,
            imageURL: signedURL.absoluteString,
            text: moment.text,
            createdAt: moment.createdAt
        )
    }
}
