import Fluent
import Vapor

enum Status: String, Codable {
    case active, inactive
}

final class Participant: Model, Content, @unchecked Sendable {
    static let schema = "participants"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "discussionId")
    var discussion: Discussion

    @Parent(key: "userId")
    var user: User

    @Timestamp(key: "joinedAt", on: .create)
    var joinedAt: Date?

    @Field(key: "status")
    var status: Status

    @Timestamp(key: "lastActiveAt", on: .update)
    var lastActiveAt: Date?

    init() {}

    init(id: UUID? = nil, discussionId: Discussion.IDValue, userId: User.IDValue, joinedAt: Date? = nil, status: Status = .inactive, lastActiveAt: Date? = nil) {
        self.id = id
        $discussion.id = discussionId
        $user.id = userId
        self.joinedAt = joinedAt
        self.status = status
        self.lastActiveAt = lastActiveAt
    }
}

extension Participant {
    struct Migration: AsyncMigration {
        var name: String { "CreateParticipant" }
        public func prepare(on database: Database) async throws {
            try await database.schema("participants")
                .id()
                .field("discussionId", .uuid, .required, .references("discussions", "id"))
                .field("userId", .uuid, .required, .references("users", "id"))
                .field("joinedAt", .datetime, .required)
                .field("status", .string, .required)
                .field("lastActiveAt", .datetime)
                .unique(on: "discussionId", "userId")
                .create()
        }

        public func revert(on database: Database) async throws {
            try await database.schema("participants").delete()
        }
    }
}

extension Participant {
    func toDictionary() -> [String: String] {
        let dateFormatter = ISO8601DateFormatter()
        let joinedAtString = dateFormatter.string(from: joinedAt!)
        let lastActiveAtString = dateFormatter.string(from: lastActiveAt!)
        return [
            "id": id?.uuidString ?? "",
            "joinedAt": joinedAtString,
            "status": status.rawValue,
            "lastActiveAt": lastActiveAtString,
        ]
    }
}

extension [Participant] {
    func toDictionary() -> [[String: String]] {
        return self.map { participant in
            participant.toDictionary()
        }
    }
}
