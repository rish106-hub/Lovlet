import Foundation

struct Pair: Codable, Identifiable {
    let id: UUID
    let user1ID: UUID
    let user2ID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case user1ID = "user1_id"
        case user2ID = "user2_id"
        case createdAt = "created_at"
    }
}

struct Moment: Codable, Identifiable {
    let id: UUID
    let pairID: UUID
    let senderID: UUID
    let imageURL: String
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairID = "pair_id"
        case senderID = "sender_id"
        case imageURL = "image_url"
        case text
        case createdAt = "created_at"
    }
}

enum WidgetMomentState: Codable {
    case noPair
    case noMoment
    case moment(WidgetMoment)
}

struct WidgetMoment: Codable {
    let text: String
    let imageURL: String
    let createdAt: Date
}
